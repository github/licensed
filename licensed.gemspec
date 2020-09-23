# coding: utf-8
# frozen_string_literal: true
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "licensed/version"

Gem::Specification.new do |spec|
  spec.name          = "licensed"
  spec.version       = Licensed::VERSION
  spec.authors       = ["GitHub"]
  spec.email         = ["opensource+licensed@github.com"]

  spec.summary       = %q{Extract and validate the licenses of dependencies.}
  spec.description   = "Licensed automates extracting and validating the licenses of dependencies."

  spec.homepage      = "https://github.com/github/licensed"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.3.0"

  spec.add_dependency "licensee", ">= 9.14.0", "< 10.0.0"
  spec.add_dependency "thor", ">= 0.19"
  spec.add_dependency "pathname-common_prefix", "~> 0.0.1"
  spec.add_dependency "tomlrb", "~> 1.2"
  spec.add_dependency "bundler", ">= 1.10"
  spec.add_dependency "ruby-xxHash", "~> 0.4"
  spec.add_dependency "parallel", ">= 0.18.0"
  spec.add_dependency "reverse_markdown", "~> 1.0"

  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "minitest", "~> 5.8"
  spec.add_development_dependency "mocha", "~> 1.0"
  spec.add_development_dependency "rubocop", "~> 0.49", "< 0.67"
  spec.add_development_dependency "rubocop-github", "~> 0.6"
  spec.add_development_dependency "byebug", "~> 10.0.0"
end
