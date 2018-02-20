# frozen_string_literal: true
require "open3"

module Licensed
  module Shell
    # Executes a command, returning it's STDOUT on success.  Returns an empty
    # string on failure
    def self.execute(cmd, *args)
      output, _, status = Open3.capture3(cmd, *args)
      return "" unless status.success?
      output.strip
    end

    # Executes a command and returns a boolean value indicating if the command
    # was succesful
    def self.success?(cmd, *args)
      _, _, status = Open3.capture3(cmd, *args)
      status.success?
    end

    # Returns a boolean indicating whether a CLI tool is available in the
    # current environment
    def self.tool_available?(tool)
      output, err, status = Open3.capture3("which", tool)
      status.success? && !output.strip.empty? && err.strip.empty?
    end
  end
end
