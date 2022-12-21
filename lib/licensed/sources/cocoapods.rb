# frozen_string_literal: true
require "json"
require "pathname"
require "uri"
require "cocoapods-core"

module Licensed
  module Sources
    class Cocoapods < Source
      def enabled?
        return unless Licensed::Shell.tool_available?("pod")

        config.pwd.join("Podfile").exist? && config.pwd.join("Podfile.lock").exist?
      end

      def enumerate_dependencies
        pods.map do |pod|
          name = pod.name
          path = dependency_path(pod.root_name)
          version = lockfile.version(name).version

          Dependency.new(
            path: path,
            name: name,
            version: version,
            metadata: { "type" => Cocoapods.type }
          )
        end
      end

      private

      def pods
        return lockfile.dependencies if targets.nil?

        targets_to_validate = podfile.target_definition_list.filter { |t| targets.include?(t.label) }
        if targets_to_validate.any?
          targets_to_validate.map(&:dependencies).flatten
        else
          raise Licensed::Sources::Source::Error, "Unable to find any target in the Podfile matching the ones provided in the config."
        end
      end

      def targets
        @targets ||= config.dig("cocoapods", "targets")&.map { |t| "Pods-#{t}" }
      end

      def lockfile
        @lockfile ||= Pod::Lockfile.from_file(config.pwd.join("Podfile.lock"))
      end

      def podfile
        @podfile ||= Pod::Podfile.from_file(config.pwd.join("Podfile"))
      end

      def dependency_path(name)
        config.pwd.join("Pods/#{name}")
      end
    end
  end
end
