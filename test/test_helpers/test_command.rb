# frozen_string_literal: true
class TestCommand < Licensed::Commands::Command
  protected

  def run_source(app, source)
    if options[:raise] == "#{app["name"]}.#{source.class.type}"
      raise Licensed::Shell::Error.new([options[:raise]], 0, nil)
    end

    super
  end

  def run_dependency(app, source, dependency)
    if options[:raise] == "#{app["name"]}.#{source.class.type}.#{dependency.name}"
      raise Licensed::Shell::Error.new([options[:raise]], 0, nil)
    end

    super
  end

  def evaluate_dependency(app, source, dependency, report)
    if options[:raise] == "#{app["name"]}.#{source.class.type}.#{dependency.name}.evaluate"
      raise Licensed::Shell::Error.new([options[:raise]], 0, nil)
    end

    return true unless options[:fail]
    options[:fail] != app["name"]
  end
end
