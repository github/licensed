# frozen_string_literal: true
require "json"

module Licensed
  module Sources
    # Only supports ProjectReference (project.assets.json) style restore used in .NET Core.
    # Does not currently support packages.config style restore.
    class NuGet < Source
      def self.type
        "nuget"
      end

      # Match nuspec license expressions like <license type="expression">MIT</license>
      class NuspecLicenseExpressionMatcher < Licensee::Matchers::Package
        LICENSE_EXPRESSION_REGEX = /
          <license\s*type\s*=\s*\"\s*expression\s*\"\s*>\s*([a-z\-0-9\.]+)\s*<\/license>
        /ix.freeze

        def license_property
          return @license_property if defined?(@license_property)
          match = @file.content.match LICENSE_EXPRESSION_REGEX
          if match && match[1]
            @license_property = match[1].downcase
          end
        end
      end

      class NuspecFile < Licensee::ProjectFiles::ProjectFile
        def possible_matchers
          [NuspecLicenseExpressionMatcher]
        end
      end

      # A pseudo-license file where the license is already known (e.g. inferred from a URL)
      class KnownLicenseFile < Licensee::ProjectFiles::ProjectFile
        def initialize(license, metadata)
          super(license.content, metadata)
          @license = license
        end

        def license
          return @license
        end

        def confidence
          100
        end
      end

      class NuGetDependency < Licensed::Dependency
        LICENSE_FILE_REGEX = /<license\s*type\s*=\s*\"\s*file\s*\"\s*>\s*(.*)\s*<\/license>/ix.freeze
        LICENSE_URL_REGEX = /<licenseUrl>\s*(.*)\s*<\/licenseUrl>/ix.freeze

        def license
          # By default, multiple of the same/similar licenses (e.g. a package with LICENSE.txt, license, and licenseUrl)
          # will incorrectly result in an "other" license.

          # Treat license expressions as most trustworthy, then local licenses, then remote licenses, then any license files
          return @license if defined? @license
          return @license = package_file.license if package_file && package_file.license
          return @license = nuspec_local_license_file.license if nuspec_local_license_file && nuspec_local_license_file.license
          return @license = nuspec_remote_license_file.license if nuspec_remote_license_file && nuspec_remote_license_file.license
          super
        end

        def package_name
          return unless @metadata
          @metadata["name"]
        end

        def package_file
          @package_file ||= NuspecFile.new(nuspec_contents, nuspec_path)
        end

        def project_files
          @project_files ||= [license_files, readme_file, package_file, nuspec_local_license_file, nuspec_remote_license_file].flatten.compact
        end

        def nuspec_path
          name = @metadata["name"]
          File.join(self.path, "#{name}.nuspec")
        end

        def nuspec_contents
          return unless nuspec_path
          @nuspec_contents ||= File.read(nuspec_path)
        end

        # Look for a <license type="file"> element in the nuspec that points to an
        # on-disk license file (which licensee may not find due to a non-standard filename)
        def nuspec_local_license_file
          return @nuspec_local_license_file if defined?(@nuspec_local_license_file)
          return unless nuspec_contents

          match = @nuspec_contents.match LICENSE_FILE_REGEX
          if match && match[1]
            license_path = File.join(File.dirname(nuspec_path), match[1])
            return unless File.exist?(license_path)
            license_data = File.read(license_path)
            @nuspec_local_license_file = Licensee::ProjectFiles::LicenseFile.new(license_data, license_path)
          end
        end

        # Look for a <licenseUrl> element in the nuspec that either is known to contain a license identifier
        # in the URL, or points to license text on the internet that can be downloaded.
        def nuspec_remote_license_file
          return @nuspec_remote_license_file if defined?(@nuspec_remote_license_file)
          return unless nuspec_contents

          match = nuspec_contents.match LICENSE_URL_REGEX
          if match && match[1]
            url = original_url = match[1]

            # Skip downloading if the URL contains a license identifier itself
            if known_license = inspect_url_for_license(url)
              return @nuspec_remote_license_file = KnownLicenseFile.new(known_license, { uri: url })
            end

            unless ignored_url?(url)
              # Transform URLs that are known to return HTML but have a corresponding text-based URL
              url = get_text_content_url(url)

              # Attempt to fetch the license content
              license_data = retrieve_license(url)
              unless license_data.nil?
                @nuspec_remote_license_file = Licensee::ProjectFiles::LicenseFile.new(license_data, { uri: original_url })
              end
            end
          end
        end

        def get_text_content_url(url)
          # Convert github file URLs to raw URLs
          if match = url.match(/https?:\/\/(?:www\.)?github.com\/([^\/]+)\/([^\/]+)\/blob\/(.*)/i)
            url = "https://github.com/#{match[1]}/#{match[2]}/raw/#{match[3]}"
          else
            url
          end
        end

        def inspect_url_for_license(url)
          if match = url.match(/https?:\/\/licenses.nuget.org\/(.*)/i)
            Licensee::License.find(match[1])
          elsif match = url.match(/https?:\/\/opensource.org\/licenses\/(.*)/i)
            Licensee::License.find(match[1])
          elsif match = url.match(/https?:\/\/(?:www\.)?apache.org\/licenses\/(.*?)(?:\.html|\.txt)?$/i)
            Licensee::License.find(match[1].gsub("LICENSE", "Apache"))
          end
        end

        def ignored_url?(url)
          url == "https://aka.ms/deprecateLicenseUrl"
        end

        def retrieve_license(url, redirect_limit = 2)
          return if redirect_limit == 0
          begin
            response = Net::HTTP.get_response(URI(url))
            case response
            when Net::HTTPSuccess     then response.body
            when Net::HTTPRedirection then retrieve_license(response["location"], redirect_limit - 1)
            end
          rescue
          end
        end
      end

      def enabled?
        nuget_config_exists(config.pwd)
      end

      def nuget_obj_root
        config.dig("nuget", "obj_root") || config.pwd
      end

      def nuget_config_exists(root)
        # Multiple supported casings: https://github.com/NuGet/Home/issues/1427
        File.exist?(File.join(root, "nuget.config")) || File.exist?(File.join(root, "NuGet.config")) || File.exist?(File.join(root, "NuGet.Config"))
      end

      def enumerate_dependencies
        packages.map do |key, package|
          NuGetDependency.new(
            name: "#{package["name"]} #{package["version"]}",
            version: package["version"],
            path: package["path"],
            metadata: {
              "type"     => NuGet.type,
              "name"     => package["name"]
            }
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
        json["targets"].keys.map do |target|
          json["targets"][target].keys.map do |reference|
            next if @packages_by_id.has_key?(reference)
            next unless json["targets"][target][reference]["type"] == "package"
            package_id_parts = reference.partition("/")
            path = File.join(nuget_packages_dir, json["libraries"][reference]["path"])
            @packages_by_id[reference] = {
              "name"    => package_id_parts[0],
              "version" => package_id_parts[-1],
              "path"    => path }
          end
        end
      end
    end
  end
end
