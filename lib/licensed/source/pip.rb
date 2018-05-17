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
          location = File.join(package["Location"], package["Name"] +  "-" + package["Version"] + ".dist-info")
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
        File.open(@config.pwd.join("requirements.txt")).map do |line|
          p_split = line.split("=")
          p_split[0]
        end
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
        venv_dir = @config.dig("python", "virtual_env_dir")
        pip = File.join(venv_dir, "bin", "pip")
        Licensed::Shell.execute(pip, "--disable-pip-version-check", "show", *args)
      end
    end
  end
end
