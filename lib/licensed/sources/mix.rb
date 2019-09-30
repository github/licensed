# frozen_string_literal: true
require "strscan"

module Licensed
  module Sources
    class Mix < Source

      LOCKFILE = "mix.lock"

      def enabled?
        File.exists?(LOCKFILE) && mix?
      end

      def enumerate_dependencies
        parsed_dependencies
      end

      # Returns whether the mix CLI tool is available
      def mix?
        @mix ||= Licensed::Shell.tool_available?("mix")
      end

      private

      # Returns a memoized Array of Dependency instances.
      def parsed_dependencies
        @parsed_dependencies ||= find_packages.map do |name, lock_info|
          convert_package_to_dependency(name, lock_info)
        end
      end

      # Returns the parsed mix.lock information as a Hash.
      def find_packages
        lockfile = File.read(LOCKFILE)
        LockfileParser.run(lockfile)
      end

      # Converts a raw package representation to a dependency.
      #
      # name      - The name of the package as a String.
      # lock_info - The parsed lockfile data for the package as an Array.
      #
      # Returns a Dependency, or raises an ArgumentError if unsuccessful.
      def convert_package_to_dependency(name, lock_info)
        package_type = lock_info.first
        case package_type
        when "git"
          git_dependency(name, lock_info)
        when "hex"
          hex_dependency(name, lock_info)
        else
          raise ArgumentError, "Unknown package type in mix.lock: #{package_type}"
        end
      end

      # Generate a Dependency for a Git-based package type.
      #
      # name      - The name of the package as a String.
      # lock_info - The parsed lockfile data for the package as an Array.
      #
      # Returns a Dependency (possibly with error information).
      def git_dependency(name, lock_info)
        # Example: {:git, "https://example.com/path/to/repo.git", "A-SHA-HERE", []},
        path, errors = check_dep_path(name)
        if lock_info.length == 4
          Dependency.new(
            name: name,
            version: lock_info[2],
            path: path,
            metadata: {
              "type" => "git",
              "repo" => lock_info[1]
            },
            errors: errors
          )
        else
          Dependency.new(
            name: name,
            path: path,
            errors: errors << "unknown mix.lock format",
            metadata: {
              "type" => "git"
            }
          )
        end
      end

      # Generate a Dependency for a Hex-based package type.
      #
      # name      - The name of the package as a String.
      # lock_info - The parsed lockfile data for the package as an Array.
      #
      # Returns a Dependency (possibly with error information).
      def hex_dependency(name, lock_info)
        # Example: {:hex, :pkgname, "1.2.3", "A-DIGEST-HERE", [:mix], [], "hexpm"}
        path, errors = check_dep_path(name)
        if lock_info.length == 7
          Dependency.new(
            name: name,
            version: lock_info[2],
            path: path,
            metadata: {
              "type" => "hex",
              "repo" => lock_info.last
            },
            errors: errors
          )
        else
          Dependency.new(
            name: name,
            path: path,
            errors: errors << "unknown mix.lock format",
            metadata: {
              "type" => "hex"
            }
          )
        end
      end

      # Check that the package has been installed in deps/.
      #
      # name - The name of the package as a String.
      #
      # Returns an Array with two members; the path as a String
      # and a possible Array of errors.
      def check_dep_path(name)
        path = dep_path(name)
        if File.directory?(path)
          return [path, []]
        else
          return [path, ["Not installed by `mix deps.get` in deps/"]]
        end
      end

      # Generate the absolute path to the named package.
      #
      # name - The name of the package dependency as a String.
      #
      # Returns a String.
      def dep_path(name)
        File.absolute_path(File.join(".", "deps", name))
      end

      class LockfileParser
        class ParseError < RuntimeError; end

        WS_PATTERN = /\s*/
        ATOM_CONTENTS_PATTERN = /[A-Za-z][A-Za-z_.0-9]+/
        SEP_PATTERN = /,\s*/

        # Parses a mix.lock to extract raw package information.
        #
        # lock - The mix.lock file contents as a String.
        #
        # Returns a Hash of package names to lockfile info, or raises a
        # ParseError if unsuccessful.
        def self.run(lock)
          new(lock).result
        end

        def initialize(lock)
          @lock = lock
          @scanner = StringScanner.new(lock)
        end

        # Builds the parser result.
        #
        # Returns a memoized Hash of package names to lockfile info, or raises a
        # ParseError if unsuccessful.
        def result
          @result ||= parse_toplevel
        end

        private

        # Parses the toplevel structure in the lockfile.
        #
        # Returns a Hash of package names to lockfile info, or
        # raises a ParseError if unsuccessful.
        def parse_toplevel
          start = @scanner.pos
          if @scanner.scan(/%\{/)
            data = {}
            loop do
              char = @scanner.peek(1)
              case char
              when "}"
                @scanner.pos += 1
                break
              when "" # EOS
                error("unterminated map", @scanner.pos)
              else
                @scanner.skip(WS_PATTERN)
                key = parse_quoted_string
                if key && @scanner.scan(/:\s+/)
                  tuple = parse_tuple
                  data[key] = tuple
                  @scanner.skip(SEP_PATTERN)
                end
              end
            end
            data
          else
            raise ParseError, "invalid mix.lock"
          end
        end

        # Parses a tuple from the current position.
        #
        # Returns a String (with quotes removed), or raises a ParseError if unsuccessful.
        def parse_quoted_string
          start = @scanner.pos
          if @scanner.scan(/"/)
            result = @scanner.scan_until(/"/)
            unless result
              raise ParseError, "quoted string not terminated (start at #{start})"
            end
            result.chop
          else
            error("expected quoted string", start)
          end
        end

        # Parses a tuple from the current position.
        #
        # Returns an Array, or raises a ParseError if unsuccessful.
        def parse_tuple
          start = @scanner.pos
          if @scanner.scan(/\{/)
            data = []
            loop do
              case @scanner.peek(1)
              when "}"
                @scanner.pos += 1
                break
              when "" # EOS
                raise ParseError, "tuple not terminated (start at #{start})"
              else
                data << parse_value(:tuple)
              end
              @scanner.skip(SEP_PATTERN)
            end
            data
          else
            error("expected tuple", start)
          end
        end

        # Parses an atom from the current position.
        #
        # Returns a String, or raises a ParseError if unsuccessful.
        def parse_atom
          start = @scanner.pos
          if @scanner.scan(/:/)
            @scanner.scan(ATOM_CONTENTS_PATTERN)
          else
            error("expected atom", start)
          end
        end

        # Parses a list from the current position.
        #
        # Returns an Array, or raises a ParseError if unsuccessful.
        def parse_list
          start = @scanner.pos
          if @scanner.scan(/\[/)
            data = []
            loop do
              char = @scanner.peek(1)
              case @scanner.peek(1)
              when "]"
                @scanner.pos += 1
                break
              when "" # EOS
                raise ParseError, "list not terminated (start at #{start})"
              else
                data << parse_value(:list)
              end
              @scanner.skip(SEP_PATTERN)
            end
            # Deal with the edge case where a non-open keyword list is wrapped
            # in an extra list.
            if data.length == 1 && data.first.is_a?(Array)
              data = data.first
            end
            data
          else
            error("expected list", start)
          end
        end

        # Parses a keyword list from the current position.
        #
        # Returns a Hash (with String keys).
        def parse_keyword_list
          data = {}
          loop do
            name = parse_keyword_name
            value = parse_value(:keyword_list)
            data[name] = value
            unless @scanner.peek(1) == ","
              break
            end
            @scanner.skip(SEP_PATTERN)
          end
          data
        end

        # Parses a keyword list from the current position.
        #
        # Returns a String or raises a ParseError if unsuccessful.
        def parse_keyword_name
          before_name = @scanner.pos
          name = @scanner.scan(ATOM_CONTENTS_PATTERN)
          unless name
            error("expected keyword", before_name)
          end

          after_name = @scanner.pos
          if @scanner.scan(/:/)
            @scanner.skip(WS_PATTERN)
            name
          else
            error("keyword #{name.inspect} not an atom", after_name)
          end
        end

        # Parses atoms, quoted strings, keyword lists, lists, and tuples from
        # the current position.
        #
        # context - The surrounding context of the value as a Symbol, used to
        #           deal with edge cases around parsing keyword lists.
        #
        # Returns a String or raises a ParseError if unsuccessful.
        def parse_value(context)
          start = @scanner.pos
          char = @scanner.peek(1)
          case char
          when ":"
            parse_atom
          when "'", "\""
            parse_quoted_string
          when /[a-z]/
            if context == :keyword_list
              # Open keyword lists can't be nested, this should be true, false, or
              # nil.
              parse_special_atom
            else
              parse_keyword_list
            end
          when /\[/
            parse_list
          when /\{/
            parse_tuple
          else
            error("unknown value", start)
          end
        end

        # Parse special atoms true, false, and nil.
        #
        # Returns true, false, or nil (or raises a ParseError if none of these
        # could be parsed).
        def parse_special_atom
          start = @scanner.pos
          case @scanner.scan(/true|false|nil/)
          when "true"
            true
          when "false"
            false
          when "nil"
            nil
          else
            error("expected true, false, or nil", start)
          end
        end

        # Raise a ParseError with position and subsequent input.
        #
        # message  - the error message as a String.
        # position - the parser byte position to report as an Integer.
        def error(message, position)
          raise ParseError, error_message(message, position)
        end

        # Format an error message with position and subsequent input.
        #
        # text     - the text that will serve as the prefix for the exception
        #            message, as a String.
        # position - the parser byte position to report as an Integer.
        #
        # Returns a String.
        def error_message(text, position)
          preview = @lock[position, 10]
          "#{text} at position #{position} near #{preview.inspect}"
        end
      end
    end
  end
end
