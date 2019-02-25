# frozen_string_literal: true
require "tempfile"
require "csv"
require "uri"
require "json"
require "net/http"

module Licensed
  module Sources
    class Gradle < Source
      def self.type
        "gradle"
      end

      def configurations
        ["runtime", "runtimeClasspath"]
      end

      def initialize(config)
        @config = config
      end

      def enabled?
        (Licensed::Shell.tool_available?("gradle") || File.executable?(@config.pwd.join("gradlew"))) && File.exist?(@config.pwd.join("build.gradle"))
      end

      def enumerate_dependencies
        @dependencies ||= JSON.parse(package_metadata_command).map do |package|
          name = "#{package["group"]}:#{package["name"]}"
          Dependency.new(
            name: name,
            version: package["version"],
            path: File.join(@config.pwd, gradle_licenses_path, name),
            metadata: {
              "type"     => Gradle.type
            }
          )
        end
      end

      def with_latest_licenses
        download_and_cache_licenses do
          yield
        end
      end

      private

      def gradle_licenses_path
        ".gradle-licenses"
      end

      def gradle_licenses_csv_name
        "licenses.csv"
      end

      def download_licenses_from_csv
        path = File.join(@config.pwd, gradle_licenses_path)
        downloaded_licenses = {}
        CSV.foreach(File.join(path, gradle_licenses_csv_name), headers: true) do |row|
          url = row["moduleLicenseUrl"]
          artifact, _, version = row["artifact"].rpartition(":")
          file_path = File.join(path, artifact, "LICENSE")
          FileUtils.mkdir_p(File.join(path, artifact))
          if cache_path = downloaded_licenses[url]
            FileUtils.cp(cache_path, file_path)
          else
            uri = URI(row["moduleLicenseUrl"])
            File.write(file_path, Net::HTTP.get(uri))
            downloaded_licenses[url] = file_path
          end
        end
      end

      def download_and_cache_licenses
        gradle_command("generateLicenseReport")
        download_licenses_from_csv
        yield
        FileUtils.rm_rf(File.join(@config.pwd, gradle_licenses_path))
      end

      # Returns the output from running `npm list` to get package metadata
      def package_metadata_command
        gradle_command("printDependencies")
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
    outputDir = "$projectDir/#{gradle_licenses_path}"
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
