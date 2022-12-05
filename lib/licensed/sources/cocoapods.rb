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
        pods.map { |pod|
          metadata = dependency_metadata(pod)
          path = dependency_path(pod.root_name)

          Dependency.new(
            path: path,
            name: metadata["name"],
            version: metadata["version"],
            metadata: {
              "type"      => Cocoapods.type,
              "homepage"  => metadata["homepage"],
              "summary"   => metadata["summary"],
              "platforms" => metadata["platform"]
            }
          )
        }
      end

      private

      def pods
        if targets.nil?
          lockfile.dependencies
        else
          targets_to_validate = podfile.target_definition_list.filter { |t| targets.include?(t.label) }
          if targets_to_validate.any?
            targets_to_validate.map(&:dependencies).flatten
          else
            raise Licensed::Sources::Source::Error, "Unable to find any target in the Podfile matching the ones provided in the config."
          end
        end
      end

      def targets
        config.dig("cocoapods", "targets")&.map { |t| "Pods-#{t}" }
      end

      def lockfile
        @lockfile ||= Pod::Lockfile.from_file(config.pwd.join("Podfile.lock"))
      end

      def podfile
        @podfile ||= Pod::Podfile.from_file(config.pwd.join("Podfile"))
      end

      def dependency_metadata(pod)
        metadata = JSON.parse(Licensed::Shell.execute("pod", "spec", "cat", "--regex", "^#{pod.root_name}$"))
        # The version returned by `pod spec cat` is the most recent version that exists which may not be the one installed.
        metadata["version"] = lockfile.version(pod.name).version
        metadata["name"] = pod.name
        metadata
      end

      def dependency_path(name)
        config.pwd.join("Pods/#{name}")
      end
    end
  end
end
