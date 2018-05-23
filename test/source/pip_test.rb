# frozen_string_literal: true
require "test_helper"
require "tmpdir"

if Licensed::Shell.tool_available?("pip")
  describe Licensed::Source::Pip do
    let (:fixtures)  { File.expand_path("../../fixtures/pip", __FILE__) }
    let (:config)   { Licensed::Configuration.new("python" => {"virtual_env_dir" => "venv"}) }
    let (:source)   { Licensed::Source::Pip.new(config) }

    describe "enabled?" do
      it "is true if pip source is available" do
        Dir.chdir(fixtures) do
        assert source.enabled?
        end
      end
    end
  end
end
