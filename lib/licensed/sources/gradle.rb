# frozen_string_literal: true
require "tempfile"
require "csv"
require "uri"
require "json"
require "net/http"
require "fileutils"

module Licensed
  module Sources
    class Gradle < Source
      DEFAULT_CONFIGURATIONS   = ["runtime", "runtimeClasspath"].freeze
      GRADLE_LICENSES_PATH     = ".gradle-licenses".freeze
      GRADLE_LICENSES_CSV_NAME = "licenses.csv".freeze
      class Dependency < Licensed::Dependency
        class << self
          # Cache and return the results of getting the license content.
          def retrieve_license(url)
            (@licenses ||= {})[url] ||= Net::HTTP.get(URI(url))
          end
        end

        def initialize(name:, version:, path:, url:, metadata: {})
          @url = url
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
          return [] if @url.nil?

          license_data = self.class.retrieve_license(@url)
          Array(Licensee::ProjectFiles::LicenseFile.new(license_data, { uri: @url }))
        end
      end

      def enabled?
        !executable.to_s.empty? && File.exist?(config.pwd.join("build.gradle"))
      end

      def enumerate_dependencies
        JSON.parse(gradle_runner.run("printDependencies", config.source_path)).map do |package|
          name = "#{package['group']}:#{package['name']}"
          Dependency.new(
            name: name,
            version: package["version"],
            path: config.pwd,
            url: package_url(name: name, version: package["version"]),
            metadata: {
              "type" => Gradle.type,
            }
          )
        end
      end

      private

      def executable
        return @executable if defined?(@executable)

        @executable = begin
          gradlew = File.join(config.pwd, "gradlew")
          return gradlew if File.executable?(gradlew)

          "gradle" if Licensed::Shell.tool_available?("gradle")
        end
      end

      def gradle_runner
        @gradle_runner ||= Runner.new(config.pwd, configurations, executable)
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

      # Returns a key to uniquely identify a name and version in the obtained CSV content
      def csv_key(name:, version:)
        "#{name}-#{version}"
      end

      def package_url(name:, version:)
        # load and memoize the license report CSV
        @urls ||= load_csv

        # uniquely identify a name and version in the obtained CSV content
        @urls["#{name}-#{version}"]
      end

      def load_csv
        begin
          # create the CSV file including dependency license urls using the gradle plugin
          gradle_licenses_dir = File.join(config.root, GRADLE_LICENSES_PATH)
          gradle_runner.run("generateLicenseReport", config.source_path)

          # parse the CSV report for dependency license urls
          CSV.foreach(File.join(gradle_licenses_dir, GRADLE_LICENSES_CSV_NAME), headers: true).each_with_object({}) do |row, hsh|
            name, _, version = row["artifact"].rpartition(":")
            key = csv_key(name: name, version: version)
            hsh[key] = row["moduleLicenseUrl"]
          end
        ensure
          FileUtils.rm_rf(gradle_licenses_dir)
        end
      end

      # Returns the cached url for the given dependency
      def url_for(dependency)
        @csv[csv_key(name: dependency.name, version: dependency.version)]
      end

      # The Gradle::Runner class is a wrapper which provides
      # an interface to run gradle commands with the init script initialized
      class Runner
        def initialize(root_path, configurations, executable)
          @root_path = root_path
          @executable = executable
          @init_script = create_init_script(root_path, configurations)
        end

        def run(command, source_path)
          args = [format_command(command, source_path)]
          # The configuration cache is an incubating feature that can be activated manually.
          # The gradle plugin for licenses does not support it so we prevent it to run for gradle version supporting it.
          args << "--no-configuration-cache" if gradle_version >= "6.6"
          Licensed::Shell.execute(@executable, "-q", "--init-script", @init_script.path, *args)
        end

        private

        def gradle_version
          @gradle_version ||= Licensed::Shell.execute(@executable, "--version").scan(/Gradle [\d+]\.[\d+]/).last.split(" ").last
        end

        def create_init_script(path, configurations)
          Dir.chdir(path) do
            f = Tempfile.new(["init", ".gradle"], @root_path)
            f.write(
              <<~EOF
                  import com.github.jk1.license.render.CsvReportRenderer
                  import com.github.jk1.license.filter.LicenseBundleNormalizer
                  final configs = #{configurations.inspect}

                  initscript {
                    repositories {
                      maven {
                        url "https://plugins.gradle.org/m2/"
                      }
                    }
                    dependencies {
                      classpath "com.github.jk1:gradle-license-report:#{gradle_version >= "7.0" ? "2.0" : "1.17"}"
                    }
                  }

                  allprojects {
                    apply plugin: com.github.jk1.license.LicenseReportPlugin
                    licenseReport {
                        outputDir = "$rootDir/.gradle-licenses"
                        configurations = configs
                        renderers = [new CsvReportRenderer()]
                        filters = [new LicenseBundleNormalizer()]
                    }

                    task printDependencies {
                      doLast {
                          def dependencies = []
                          configs.each {
                              configurations[it].resolvedConfiguration.resolvedArtifacts.each { artifact ->
                                  def id = artifact.moduleVersion.id
                                  dependencies << "{ \\"group\\": \\"${id.group}\\", \\"name\\": \\"${id.name}\\", \\"version\\": \\"${id.version}\\" }"
                              }
                          }
                          println "[${dependencies.join(", ")}]"
                      }
                    }
                  }
                EOF
              )
            f.close
            f
          end
        end

        # Prefixes the gradle command with the project name for multi-build projects.
        def format_command(command, source_path)
          Dir.chdir(source_path) do
            path = Licensed::Shell.execute(@executable, "properties", "-Dorg.gradle.logging.level=quiet").scan(/path:.*/).last.split(" ").last
            path == ":" ? command : "#{path}:#{command}"
          end
        end
      end
    end
  end
end
