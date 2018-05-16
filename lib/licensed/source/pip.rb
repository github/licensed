# frozen_string_literal: true
require "json"
require "English"

module Licensed
  module Source
    class Pip
      def initialize(config)
        @config = config
      end

      def type
        "pip"
      end

      def enabled?
        @config.enabled?(type) && File.exist?(@config.pwd.join("requirements.txt"))
      end

      def dependencies
        @dependencies ||= parse_requirements_txt.map do |package_name|
            package = package_info(package_name)
            location = File.join(package["Location"], "-" + package["Version"] + ".dist-info")
            Dependency.new(location, {
              "type"        => type,
              "name"        => package["Name"],
              "summary"     => package["Summary"],
              "homepage"    => package["Home-page"],
              "version"     => package["Version"]
            })
        end
      end

      # Build the list of packages from a 'requirements.txt'
      # Assumes that the requirements.txt follow the format pkg=1.0.0 or pkg==1.0.0
      def parse_requirements_txt
        packages = []
        File.open(@config.pwd.join("requirements.txt")).each do |line|
          p_split = line.split("=")
          packages.push(p_split[0])
        end
        packages
      end

      def package_info(package_name)
        info = {}
        p_info = pip_command(package_name).split("\n")
        p_info.each do |pkg|
          k, v = pkg.split(":", 2)
          info[k&.strip] = v&.strip
        end
        info
      end

      def pip_command(*args)
        venv_dir = @config.dig("python", "virtual_env_dir")
        pip = File.join(venv_dir, "bin", "pip")
        Licensed::Shell.execute(pip, "--disable-pip-version-check", "show", *args)
      end
    end
  end
end
