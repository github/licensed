# frozen_string_literal: true
require "yaml"
require "fileutils"
require "forwardable"
require "licensee"

module Licensed
  class License
    include Licensee::ContentHelper
    extend Forwardable

    YAML_FRONTMATTER_PATTERN = /\A---\s*\n(.*?\n?)^---\s*$\n?(.*)\z/m
    TEXT_SEPARATOR = ("-" * 80).freeze

    # Read an existing license file
    #
    # filename - A String path to the file
    #
    # Returns a Licensed::License
    def self.read(filename)
      return unless File.exist?(filename)
      match = File.read(filename).scrub.match(YAML_FRONTMATTER_PATTERN)
      new(YAML.load(match[1]), match[2])
    end

    def_delegators :@metadata, :[], :[]=

    # The license text and other legal notices
    attr_accessor :text

    # Construct a new license
    #
    # filename - the String path of the file
    # metadata - a Hash of the metadata for the package
    # text     - a String of the license text and other legal notices
    def initialize(metadata = {}, text = nil)
      @metadata = metadata
      @text = text
    end

    # Save the metadata and license to a file
    def save(filename)
      FileUtils.mkdir_p(File.dirname(filename))
      File.write(filename, YAML.dump(@metadata) + "---\n#{text}")
    end

    # Returns the license text without any notices
    def license_text
      return unless text

      # if the text contains the separator, the first string in the array
      # should always be the license text whether empty or not.
      # if the text didn't contain the separator, the text itself is the entirety
      # of the license text
      split = text.split(TEXT_SEPARATOR)
      split.length > 1 ? split.first.strip : text.strip
    end
    alias_method :content, :license_text # use license_text for content matching

    # Returns whether the current license should be updated to `other`
    # based on whether the normalized license content matches
    def license_text_match?(other)
      return false unless other.is_a?(License)
      self.content_normalized == other.content_normalized
    end
  end
end
