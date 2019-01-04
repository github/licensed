# frozen_string_literal: true
require "yaml"
require "fileutils"
require "forwardable"
require "licensee"

module Licensed
  class DependencyRecord
    include Licensee::ContentHelper
    extend Forwardable

    TEXT_SEPARATOR = ("-" * 80).freeze
    LICENSE_SEPARATOR = ("*" * 80).freeze
    LICENSE_FILE_PATTERN = /\A
      ---\s*
      (.*?)\s*
      ---\s*
      ((.*?(\s*#{Regexp.escape(LICENSE_SEPARATOR)}\s*)?)*)
      ((\s*#{Regexp.escape(TEXT_SEPARATOR)}\s*.*?)*)?
      \s*
    \z/mx

    # Read an existing record file
    #
    # filename - A String path to the file
    #
    # Returns a Licensed::DependencyRecord
    def self.read(filename)
      return unless File.exist?(filename)
      match = File.read(filename).scrub.match(LICENSE_FILE_PATTERN)
      return unless match

      metadata = YAML.load(match[1])
      licenses = match[2].split("\n#{LICENSE_SEPARATOR}\n").reject(&:empty?)
      notices = match[5].split("\n#{TEXT_SEPARATOR}\n").reject(&:empty?)
      new(licenses: licenses, notices: notices, metadata: metadata)
    end

    def_delegators :@metadata, :[], :[]=
    attr_reader :licenses
    attr_reader :notices

    # Construct a new record
    #
    # licenses - a string, or array of strings, representing the content of each license
    # notices - a string, or array of strings, representing the content of each legal notice
    # metadata - a Hash of the metadata for the package
    def initialize(licenses: [], notices: [], metadata: {})
      @licenses = Array(licenses).compact
      @notices = Array(notices).compact
      @metadata = metadata
    end

    # Save the metadata and text to a file
    #
    # filename - The destination file to save record contents at
    def save(filename)
      FileUtils.mkdir_p(File.dirname(filename))
      File.open(filename, "w") do |f|
        f.puts YAML.dump(@metadata).strip
        f.puts "---"
        f.puts licenses.join("\n#{LICENSE_SEPARATOR}\n") if licenses.any?
        if notices.any?
          f.puts TEXT_SEPARATOR
          f.puts notices.join("\n#{TEXT_SEPARATOR}\n")
        end
      end
    end

    # Returns the content used to compare two licenses using normalization from
    # `Licensee::CotentHelper`
    def content
      return if licenses.nil? || licenses.empty?
      licenses.join
    end

    # Returns whether two records match based on their contents
    def matches?(other)
      return false unless other.is_a?(DependencyRecord)
      return false if self.content_normalized.nil?

      self.content_normalized == other.content_normalized
    end
  end
end
