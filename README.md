# Licensed

Licensed is a Ruby gem to cache the licenses of dependencies and check their status.

Licensed is **not** a complete open source license compliance solution. Please understand the important [disclaimer](#disclaimer) below to make appropriate use of Licensed.

## Current Status

[![Build Status](https://travis-ci.org/github/licensed.svg?branch=master)](https://travis-ci.org/github/licensed)

Licensed is in active development and currently used at GitHub.  See the [open issues](https://github.com/github/licensed/issues) for a list of potential work.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'licensed', :group => 'development'
```

And then execute:

```bash
$ bundle
```

#### Dependencies

Licensed uses the the `libgit2` bindings for Ruby provided by `rugged`. `rugged` has its own dependencies - `cmake` and `pkg-config` - which you may need to install before you can install Licensed.

For example, on macOS with Homebrew: `brew install cmake pkg-config` and on Ubuntu: `apt-get install cmake pkg-config`.

## Usage

- `licensed list`: Output enumerated dependencies only.

- `licensed cache`: Cache licenses and metadata.

- `licensed status`: Check status of dependencies' cached licenses. For example:

```
$ bundle exec licensed status
Checking licenses for 3 dependencies

Warnings:

.licenses/rubygem/bundler.txt:
  - license needs reviewed: mit.

.licenses/rubygem/licensee.txt:
  - cached license data missing

.licenses/bower/jquery.txt:
  - license needs reviewed: mit.
  - cached license data out of date

3 dependencies checked, 3 warnings found.
```

### Configuration

All commands accept a `-c|--config` option to specify a path to a configuration file or directory.

If a directory is specified, `licensed` will look in that directory for a file named (in order of preference):
1. `.licensed.yml`
2. `.licensed.yaml`
3. `.licensed.json`

If the option is not specified, the value will be set to the current directory.

See the [configuration file documentation](./docs/configuration.md) for more details on the configuration format.

### Sources

Dependencies will be automatically detected for
1. [Bower](./docs/sources/bower.md)
2. [Bundler (rubygem)](./docs/sources/bundler.md)
3. [Cabal](./docs/sources/cabal.md)
4. [Go](./docs/sources/go.md)
5. [Manifest lists](./docs/sources/manifests.md)
6. [NPM](./docs/sources/npm.md)

You can disable any of them in the configuration file:

```yml
sources:
  rubygem: false
  npm: false
  bower: false
  cabal: false
```

## Development

After checking out the repo, run `script/bootstrap` to install dependencies. Then, run `script/cibuild` to run the tests. You can also run `script/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

#### Adding sources

When adding new dependency sources, ensure that `script/bootstrap` scripting and tests are only run if the required tooling is available on the development machine.

* See `script/bootstrap` for examples of gating scripting based on whether tooling executables are found.
* Use `Licensed::Shell.tool_available?` when writing test files to gate running a test suite when tooling executables aren't available.
```ruby
if Licensed::Shell.tool_available?('bundle')
  describe Licensed::Source::Bundler do
    ...
  end
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/github/licensed. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org/) code of conduct.  See [CONTRIBUTING](CONTRIBUTING.md) for more details.

## Disclaimer

Licensed is **not** a complete open source license compliance solution. Like any bug, licensing issues are far cheaper to fix if found early. Licensed is intended to provide automation around documenting the licenses of dependencies and whether they  are configured to be allowed by a user of licensed, in other words, to surface the most obvious licensing issues early.

Licensed is not a substitute for human review of each dependency for licensing or any other issues. It is not the goal of Licensed or GitHub, Inc. to provide legal advice about licensing or any other issues. If you have any questions regarding licensing compliance for your code or any other legal issues relating to it, it’s up to you to do further research or consult with a professional.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
