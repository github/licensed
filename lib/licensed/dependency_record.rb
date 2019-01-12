# frozen_string_literal: true
require "fileutils"
require "forwardable"
require "licensee"

module Licensed
  class DependencyRecord
    include Licensee::ContentHelper
    extend Forwardable

    EXTENSION = "dep.yml".freeze

    # Read an existing record file
    #
    # filename - A String path to the file
    #
    # Returns a Licensed::DependencyRecord
    def self.read(filename)
      return unless File.exist?(filename)
      data = YAML.load_file(filename)
      return if data.nil? || data.empty?
      new(
        licenses: data.delete("licenses"),
        notices: data.delete("notices"),
        metadata: data
      )
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
      @licenses = [licenses].flatten.compact
      @notices = [notices].flatten.compact
      @metadata = metadata
    end

    # Save the metadata and text to a file
    #
    # filename - The destination file to save record contents at
    def save(filename)
      data_to_save = @metadata.merge({
        "licenses" => licenses,
        "notices" => notices
      })

      FileUtils.mkdir_p(File.dirname(filename))
      File.write(filename, data_to_save.to_yaml)
    end

    # Returns the content used to compare two licenses using normalization from
    # `Licensee::CotentHelper`
    def content
      return if licenses.nil? || licenses.empty?
      licenses.map do |license|
        if license.is_a?(String)
          license
        elsif license.respond_to?(:[])
          license["text"]
        end
      end.join
    end

    # Returns whether two records match based on their contents
    def matches?(other)
      return false unless other.is_a?(DependencyRecord)
      return false if self.content.nil?

      self.content_normalized == other.content_normalized
    end
  end
end
