# frozen_string_literal: true
require "licensed/shell"

module Licensed
  module Migrations
    class V2
      def self.migrate(config_path, shell = Licensed::UI::Shell.new)
        shell.info "updating to v2"

        shell.info "updating bundler configuration keys"
        # replace all "rubygem" and "rubygems" configuration keys with "bundler"
        # to account for the bundler source's `type` change from `rubygem` to `bundler`
        File.write(config_path, File.read(config_path).gsub(/rubygems?:/, "bundler:"))

        shell.info "updating cached records"
        # load the configuration to find and update cached contents
        configuration = Licensed::Configuration.load_from(config_path)
        configuration.apps.each do |app|
          Dir.chdir app.cache_path do
            # licensed v1 cached records were stored as .txt files with YAML frontmatter
            Dir["**/*.txt"].each do |file|
              # find the yaml and non-yaml data by parsing the yaml data out of the contents
              # then reserializing the contents to a string that can be stripped from the
              # original file contents
              cached_contents = File.read(file)
              yaml = YAML.load(cached_contents)
              cached_contents = cached_contents.gsub(yaml.to_yaml + "---", "")

              # in v1, licenses and notices are separated by special text dividers
              # in v2, cached records are defined and formatted entirely in yaml
              licenses, *notices = cached_contents.split(("-") * 80).map(&:strip)
              licenses = licenses.split(("*") * 80).map(&:strip)
              yaml["licenses"] = licenses.map { |text| { "text" => text } }
              yaml["notices"] = notices.map { |text| { "text" => text } }

              # v2 records are stored in `.dep.yml` files
              # write the new yaml contents to the new file and delete old file
              new_file = file.gsub(".txt", ".dep.yml")
              File.write(new_file, yaml.to_yaml)
              File.delete(file)
            end
          end
        end
      end
    end
  end
end
