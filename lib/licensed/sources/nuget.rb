# frozen_string_literal: true
require "json"
require "reverse_markdown"

module Licensed
  module Sources
    # Only supports ProjectReference (project.assets.json) style restore used in .NET Core.
    # Does not currently support packages.config style restore.
    class NuGet < Source
      def self.type
        "nuget"
      end

      class NuGetDependency < Licensed::Dependency
        LICENSE_FILE_REGEX = /<license\s*type\s*=\s*\"\s*file\s*\"\s*>\s*(.*)\s*<\/license>/ix.freeze
        LICENSE_URL_REGEX = /<licenseUrl>\s*(.*)\s*<\/licenseUrl>/ix.freeze
        PROJECT_URL_REGEX = /<projectUrl>\s*(.*)\s*<\/projectUrl>/ix.freeze

        def initialize(name:, version:, path:, search_root: nil, metadata: {}, errors: [])
          super(name: name, version: version, path: path, search_root: search_root, metadata: metadata, errors: errors)
          @metadata["homepage"] = project_url if project_url
        end

        def nuspec_path
          name = @metadata["name"]
          File.join(self.path, "#{name}.nuspec")
        end

        def nuspec_contents
          return unless nuspec_path
          @nuspec_contents ||= File.read(nuspec_path)
        end

        def project_url
          return unless nuspec_contents
          @project_url ||= begin
            match = nuspec_contents.match PROJECT_URL_REGEX
            match[1] if match && match[1]
          end
        end

        def project_files
          @nuget_project_files ||= begin
            files = [super(), nuspec_local_license_file].flatten.compact

            # Only download licenseUrl if no recognized license was found locally
            if files.none? { |file| file.license && file.license.key != "other" }
              files.push(nuspec_remote_license_file)
            end
            files.compact
          end
        end

        # Look for a <license type="file"> element in the nuspec that points to an
        # on-disk license file (which licensee may not find due to a non-standard filename)
        def nuspec_local_license_file
          return @nuspec_local_license_file if defined?(@nuspec_local_license_file)
          return unless nuspec_contents

          match = nuspec_contents.match LICENSE_FILE_REGEX
          return unless match && match[1]

          license_path = File.join(File.dirname(nuspec_path), match[1])
          return unless File.exist?(license_path)

          license_data = File.read(license_path)
          @nuspec_local_license_file = Licensee::ProjectFiles::LicenseFile.new(license_data, license_path)
        end

        # Look for a <licenseUrl> element in the nuspec that either is known to contain a license identifier
        # in the URL, or points to license text on the internet that can be downloaded.
        def nuspec_remote_license_file
          return @nuspec_remote_license_file if defined?(@nuspec_remote_license_file)
          return unless nuspec_contents

          match = nuspec_contents.match LICENSE_URL_REGEX
          return unless match && match[1]

          # Attempt to fetch the license content
          license_content = self.class.retrieve_license(match[1])
          @nuspec_remote_license_file = Licensee::ProjectFiles::LicenseFile.new(license_content, { uri: match[1] }) if license_content
        end

        class << self
          def strip_html(html)
            return unless html

            if html.downcase.include?("<html")
              ReverseMarkdown.convert(html, unknown_tags: :bypass)
            else
              html
            end
          end

          def ignored_url?(url)
            # Many Microsoft packages that now use <license> use this for <licenseUrl>
            # No need to fetch this page - it just contains NuGet documentation
            url == "https://aka.ms/deprecateLicenseUrl"
          end

          def text_content_url(url)
            # Convert github file URLs to raw URLs
            return url unless match = url.match(/https?:\/\/(?:www\.)?github.com\/([^\/]+)\/([^\/]+)\/blob\/(.*)/i)
            "https://github.com/#{match[1]}/#{match[2]}/raw/#{match[3]}"
          end

          def retrieve_license(url)
            return unless url
            return if ignored_url?(url)

            # Transform URLs that are known to return HTML but have a corresponding text-based URL
            text_url = text_content_url(url)

            raw_content = fetch_content(text_url)
            strip_html(raw_content)
          end

          def fetch_content(url, redirect_limit = 5)
            url = URI.parse(url) if url.instance_of? String
            return @response_by_url[url] if (@response_by_url ||= {}).key?(url)
            return if redirect_limit == 0

            begin
              response = Net::HTTP.get_response(url)
              case response
              when Net::HTTPSuccess     then
                @response_by_url[url] = response.body
              when Net::HTTPRedirection then
                redirect_url = URI.parse(response["location"])
                if redirect_url.relative?
                  redirect_url = url + redirect_url
                end
                # The redirect might be to a URL that requires transformation, i.e. a github file
                redirect_url = text_content_url(redirect_url.to_s)
                @response_by_url[url] = fetch_content(redirect_url, redirect_limit - 1)
              end
            rescue => error
              # Host might no longer exist or some other error, ignore
            end
          end
        end
      end

      def enabled?
        nuget_config_exists(config.pwd)
      end

      def nuget_obj_root
        config.dig("nuget", "obj_root") || config.pwd
      end

      def dump_projects?
        config.dig("nuget", "projects", "dump")
      end

      def exclude_projects
        config.dig("nuget", "projects", "exclude") || []
      end

      def excluded_project?(project_name)
        exclude_projects.any? do |pattern|
          File.fnmatch?(pattern, project_name, File::FNM_PATHNAME | File::FNM_CASEFOLD)
        end
      end

      def nuget_config_exists(root)
        # Multiple supported casings: https://github.com/NuGet/Home/issues/1427
        File.exist?(File.join(root, "nuget.config")) || File.exist?(File.join(root, "NuGet.config")) || File.exist?(File.join(root, "NuGet.Config"))
      end

      def enumerate_dependencies
        packages.map do |key, package|
          metadata = {
            "type" => NuGet.type,
            "name" => package["name"]
          }

          # Emit the names of the projects that consume a particular dependency.
          # Useful for determining projects to exclude.
          metadata["projects"] = package["projects"].to_a.sort if dump_projects?

          NuGetDependency.new(
            name: "#{package["name"]}-#{package["version"]}",
            version: package["version"],
            path: package["path"],
            metadata: metadata
          )
        end
      end

      # Inspect project.assets.json files for package references.
      # Ideally we'd use `dotnet list package` instead, but its output isn't
      # easily machine readable, and it also requires repos to have a .sln file
      # to evaluate multiple projects.
      def packages
        return @packages_by_id if defined?(@packages_by_id)
        @packages_by_id = Hash.new
        Dir.glob(File.join(nuget_obj_root, "**/project.assets.json")).map do |file|
          gather_packages(file)
        end
        @packages_by_id
      end

      def gather_packages(project_assets_file)
        json = JSON.parse(File.read(project_assets_file))
        nuget_packages_dir = json["project"]["restore"]["packagesPath"]
        project_name = json["project"]["restore"]["projectName"]
        return if excluded_project?(project_name)

        json["targets"].map do |target_key, target|
          target.map do |reference_key, reference|
            next unless reference["type"] == "package"
            package_id_parts = reference_key.partition("/")
            path = File.join(nuget_packages_dir, json["libraries"][reference_key]["path"])
            if @packages_by_id.key?(reference)
              @packages_by_id[reference_key]["projects"].add(project_name)
            else
              @packages_by_id[reference_key] = {
                "name"     => package_id_parts[0],
                "version"  => package_id_parts[-1],
                "path"     => path,
                "projects" => Set.new([project_name])
              }
            end
          end
        end
      end
    end
  end
end
