# frozen_string_literal: true

require "English"
require "json"
require "parallel"

module Licensed
  module Sources
    class Pip < Source
      VERSION_OPERATORS = %w(< > <= >= == !=).freeze
      PACKAGE_REGEX = /^([\w\.-]+)(#{VERSION_OPERATORS.join("|")})?/

      def enabled?
        return unless virtual_env_pip && Licensed::Shell.tool_available?(virtual_env_pip)
        File.exist?(config.pwd.join("requirements.txt"))
      end

      def enumerate_dependencies
        Parallel.map(packages_from_requirements_txt, in_threads: Parallel.processor_count) do |package_name|
          package = package_info(package_name)
          location = File.join(package["Location"], package["Name"].gsub("-", "_") +  "-" + package["Version"] + ".dist-info")
          Dependency.new(
            name: package["Name"],
            version: package["Version"],
            path: location,
            metadata: {
              "type"        => Pip.type,
              "summary"     => package["Summary"],
              "homepage"    => package["Home-page"]
            }
          )
        end
      end

      private

      def packages_from_requirements_txt
        File.read(config.pwd.join("requirements.txt"))
            .lines
            .reject { |line| line.include?("://") }
            .map { |line| line.strip.match(PACKAGE_REGEX) { |match| match.captures.first } }
            .compact
      end

      def package_info(package_name)
        p_info = pip_command(package_name).lines
        p_info.each_with_object(Hash.new(0)) { |pkg, a|
          k, v = pkg.split(":", 2)
          next if k.nil? || k.empty?
          a[k.strip] = v&.strip
        }
      end

      def pip_command(*args)
        Licensed::Shell.execute(virtual_env_pip, "--disable-pip-version-check", "show", *args)
      end

      def virtual_env_pip
        return unless virtual_env_dir
        File.join(virtual_env_dir, "bin", "pip")
      end

      def virtual_env_dir
        return @virtual_env_dir if defined?(@virtual_env_dir)
        @virtual_env_dir = begin
          venv_dir = config.dig("python", "virtual_env_dir")
          File.expand_path(venv_dir, config.root) if venv_dir
        end
      end
    end
  end
end
