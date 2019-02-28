# frozen_string_literal: true
require "tempfile"
require "csv"
require "uri"
require "json"
require "net/http"

module Licensed
  module Sources
    class Gradle < Source

      DEFAULT_CONFIGURATIONS   = ["runtime", "runtimeClasspath"].freeze
      GRADLE_LICENSES_PATH     = ".gradle-licenses".freeze

      class Dependency < Licensed::Dependency
        GRADLE_LICENSES_CSV_NAME = "licenses.csv".freeze

        class << self
          # Returns a key to uniquely identify a name and version in the obtained CSV content
          def csv_key(name:, version:)
            "#{name}-#{version}"
          end

          # Loads and caches license report CSV data as a hash of :name-:version => :url pairs
          #
          # configurations - The gradle configurations to generate license information for
          #
          # Returns a hash of dependency identifiers to their license content URL
          def load_csv(configurations)
            @csv ||= begin
              Licensed::Sources::Gradle.gradle_command("generateLicenseReport", configurations: configurations)
              CSV.foreach(File.join(path, GRADLE_LICENSES_CSV_NAME), headers: true).each_with_object({}) do |row, hsh|
                name, _, version = row["artifact"].rpartition(":")
                key = csv_key(name: name, version: version)
                hsh[key] = row["moduleLicenseUrl"]
              end
            end
          end

          # Returns the cached url for the given dependency
          def url_for(dependency)
            @csv[csv_key(name: dependency.name, version: dependency.version)]
          end

          # Cache and return the results of getting the license content.
          def license(url)
            (@licenses ||= {})[url] ||= Net::HTTP.get(uri)
          end
        end

        def initialize(name:, version:, path:, configurations:, metadata: {})
          @configuration = configurations
          super(name: name, version: version, path: path, metadata: metadata)
        end

        # Returns whether the dependency content exists
        def exist?
          # shouldn't force network connections just to check if content exists
          # only check that the path is not empty
          !path.to_s.empty?
        end

        # Returns a Licensee::ProjectFiles::LicenseFile for the dependency
        def project_files
          self.class.load_csv(@configurations)

          url = self.class.url_for(self)
          Array(Licensee::ProjectFiles::LicenseFile.new(self.class.license(url), url))
        end
      end

      def enabled?
        (Licensed::Shell.tool_available?("gradle") || File.executable?(@config.pwd.join("gradlew"))) && File.exist?(@config.pwd.join("build.gradle"))
      end

      def enumerate_dependencies
        JSON.parse(gradle_command("printDependencies", configurations: configurations)).map do |package|
          name = "#{package["group"]}:#{package["name"]}"
          Dependency.new(
            name: name,
            version: package["version"],
            path: gradle_licenses_path,
            configurations: configurations,
            metadata: {
              "type"     => Gradle.type
            }
          )
        end
      end

      private

      def gradle_licenses_path
        @gradle_licenses_path ||= File.join(config.pwd, GRADLE_LICENSES_PATH)
      end

      # Returns the configurations to include in license generation.
      # Defaults to ["runtime", "runtimeClasspath"]
      def configurations
        @configurations ||= begin
          if configurations = config.dig("gradle", "configurations")
            Array(configurations)
          else
            DEFAULT_CONFIGURATIONS
          end
        end
      end

      def self.gradle_command(*args, configurations:)
        Tempfile.create do |f|
          f.write gradle_file(configurations)
          f.close
          Licensed::Shell.execute(executable, "-q", "-b", f.path, *args)
        end
      end

      def self.executable
        if File.executable?(File.join(config.pwd, "gradlew"))
          "./gradlew"
        else
          "gradle"
        end
      end

      def self.gradle_file(configurations)
        <<~EOF
          plugins {
              id "com.github.jk1.dependency-license-report" version "1.4"
          }

          import com.github.jk1.license.render.CsvReportRenderer
          import com.github.jk1.license.filter.LicenseBundleNormalizer

          final configs = #{configurations.inspect}

          apply from: "build.gradle"

          licenseReport {
              configurations = configs
              outputDir = "$projectDir/#{GRADLE_LICENSES_PATH}"
              renderers = [new CsvReportRenderer()]
              filters = [new LicenseBundleNormalizer()]
          }

          task printDependencies {
              doLast {
                  def dependencies = []
                  configs.each {
                      configurations[it].resolvedConfiguration.resolvedArtifacts.each { artifact ->
                          def id = artifact.moduleVersion.id
                          dependencies << "  { \\"group\\": \\"${id.group}\\", \\"name\\": \\"${id.name}\\", \\"version\\": \\"${id.version}\\" }"
                      }
                  }
                  println "[\\n${dependencies.join(", ")}\\n]"
              }
          }
        EOF
      end
    end
  end
end
