# frozen_string_literal: true

require "parallel"

module Licensed
  module Sources
    class Pipenv < Source
      def enabled?
        Licensed::Shell.tool_available?("pipenv") && File.exist?(config.pwd.join("Pipfile.lock"))
      end

      def enumerate_dependencies
        Parallel.map(pakages_from_pipfile_lock, in_threads: Parallel.processor_count) do |package_name|
          package = package_info(package_name)
          location = File.join(package["Location"], package["Name"].gsub("-", "_") +  "-" + package["Version"] + ".dist-info")
          Dependency.new(
            name: package["Name"],
            version: package["Version"],
            path: location,
            metadata: {
              "type"        => Pipenv.type,
              "summary"     => package["Summary"],
              "homepage"    => package["Home-page"]
            }
          )
        end
      end

      private

      def pakages_from_pipfile_lock
        Licensed::Shell.execute("pipenv", "run", "pip", "list")
            .lines
            .drop(2)  # Header
            .map { |line| line.strip.split.first.strip }
      end

      def package_info(package_name)
        p_info = Licensed::Shell.execute("pipenv", "run", "pip", "--disable-pip-version-check", "show", package_name).lines
        p_info.each_with_object(Hash.new(0)) { |pkg, a|
          k, v = pkg.split(":", 2)
          next if k.nil? || k.empty?
          a[k.strip] = v&.strip
        }
      end
    end
  end
end
