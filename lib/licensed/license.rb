# frozen_string_literal: true
require "yaml"
require "fileutils"
require "forwardable"

module Licensed
  class License
    YAML_FRONTMATTER_PATTERN = /\A---\s*\n(.*?\n?)^---\s*$\n?(.*)\z/m
    LEGAL_FILES = /\A(COPYING|NOTICE|LEGAL)(?:\..*)?\z/i

    # Read an existing license file
    #
    # filename - A String path to the file
    #
    # Returns a Licensed::License
    def self.read(filename)
      match = File.read(filename).scrub.match(YAML_FRONTMATTER_PATTERN)
      new(YAML.load(match[1]), match[2])
    end

    extend Forwardable
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
  end
end
