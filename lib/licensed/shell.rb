# frozen_string_literal: true
require "open3"

module Licensed
  module Shell
    # Executes a command, returning its standard output on success. On failure,
    # it raises an exception that contains the error output, unless
    # `allow_failure` is true, in which case it returns an empty string.
    def self.execute(cmd, *args, allow_failure: false)
      stdout, stderr, status = Open3.capture3(cmd, *args)

      if status.success?
        stdout.strip
      elsif allow_failure
        ""
      else
        raise Error.new([cmd, *args], status.exitstatus, stderr)
      end
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

    class Error < RuntimeError
      def initialize(cmd, status, stderr)
        super()
        @cmd = cmd
        @exitstatus = status
        @output = stderr
      end

      def message
        output = @output.to_s.strip
        extra = output.empty?? "" : "\n#{output.gsub(/^/, "    ")}"
        "command exited with status #{@exitstatus}\n  #{escape_cmd}#{extra}"
      end

      def escape_cmd
        @cmd.map do |arg|
          if arg =~ /[\s'"]/
            escaped = arg.gsub(/([\\"])/, '\\\\\1')
            %("#{escaped}")
          else
            arg
          end
        end.join(" ")
      end
    end
  end
end
