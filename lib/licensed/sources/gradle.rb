# frozen_string_literal: true
require "tempfile"
require "csv"
require "uri"
require "json"
require "net/http"

module Licensed
  module Sources
    class Gradle < Source

      DEFAULT_CONFIGURATIONS   = ["runtime", "runtimeClasspath"]
      GRADLE_LICENSES_PATH     = ".gradle-licenses"
      GRADLE_LICENSES_CSV_NAME = "licenses.csv"

      class Dependency < Licensed::Dependency
        class << self
          # Cache and return the results of getting the license content.
          def license(url)
            (@licenses ||= {})[url] ||= Net::HTTP.get(uri)
          end
        end

        # Returns whether the dependency content exists
        def exist?
          # shouldn't force network connections just to check if content exists
          # only check that the path is not empty
          !path.to_s.empty?
        end

        # Returns a Licensee::ProjectFiles::LicenseFile for the dependency
        def project_files
          return [] if path.to_s.empty?
          Array(Licensee::ProjectFiles::LicenseFile.new(self.class.license(path), path))
        end
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

      def enabled?
        (Licensed::Shell.tool_available?("gradle") || File.executable?(@config.pwd.join("gradlew"))) && File.exist?(@config.pwd.join("build.gradle"))
      end

      def enumerate_dependencies
        packages.map do |package|
          name = "#{package["group"]}:#{package["name"]}"
          Dependency.new(
            name: name,
            version: package["version"],
            path: package["url"],
            metadata: {
              "type"     => Gradle.type
            }
          )
        end
      end

      private

      def packages
        metadata = JSON.parse(gradle_command("printDependencies"))
        gradle_command("generateLicenseReport")
        path = File.join(@config.pwd, GRADLE_LICENSES_PATH)
        CSV.foreach(File.join(path, GRADLE_LICENSES_CSV_NAME), headers: true) do |row|
          artifact, _, version = row["artifact"].rpartition(":")
          package = metadata.find { |p| p["name"] == artifact && p["version"] == version }
          next unless package
          package["url"] = row["moduleLicenseUrl"]
        end

        metadata
      end

      def gradle_command(*args)
        Tempfile.open(["license", ".gradle"], @config.pwd) do |f|
          f.write gradle_file
          f.close
          Licensed::Shell.execute(executable, "-q", "-b", f.path, *args)
        end
      end

      def executable
        if File.executable?(File.join(@config.pwd, "gradlew"))
          "./gradlew"
        else
          "gradle"
        end
      end

      def gradle_file
        <<-EOF
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
