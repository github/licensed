# Licensed

Licensed caches the licenses of dependencies and checks their status.

Licensed is available as a Ruby gem for Ruby environments, and as a self-contained executable for non-Ruby environments.

Licensed is **not** a complete open source license compliance solution. Please understand the important [disclaimer](#disclaimer) below to make appropriate use of Licensed.

## Current Status

![Build status](https://github.com/github/licensed/workflows/Test/badge.svg)

Licensed is in active development and currently used at GitHub.  See the [open issues](https://github.com/github/licensed/issues) for a list of potential work.

## Licensed v3

Licensed v3 includes a breaking change if both of the following are true:

1. a project uses bundler to manage ruby dependencies
2. a project uses the self-contained executable build of licensed

All other usages of licensed should not encounter any major changes migrating from the latest 2.x build to 3.0.  

See [CHANGELOG.md](./CHANGELOG.md) for more details on what's changed.
See the [v3 migration documentation](./docs/migrations/v3.md) for more info on migrating to v3.

## Licensed v2

Licensed v2 includes many internal changes intended to make licensed more extensible and easier to update in the future.  While not too much has changed externally, v2 is incompatible with configuration files and cached records from previous versions.  Fortunately, migrating is easy using the `licensed migrate` command.

See [CHANGELOG.md](./CHANGELOG.md) for more details on what's changed.
See the [v2 migration documentation](./docs/migrations/v2.md) for more info on migrating to v2, or run `licensed help migrate`.

## Installation

### Dependencies

Licensed uses the `libgit2` bindings for Ruby provided by `rugged`. `rugged` requires `cmake` and `pkg-config` which you may need to install before you can install Licensed.

```bash
# Ubuntu
sudo apt-get install cmake pkg-config

# macOS
brew install cmake pkg-config
```

### With a Gemfile

Add this line to your application's Gemfile:

```ruby
gem 'licensed', :group => 'development'
```

And then execute:

```bash
$> bundle
```

### As an executable

Download a package from GitHub and extract the executable.  Executable packages are available for each release starting with version 1.2.0.

```bash
$> curl -sSL https://github.com/github/licensed/releases/download/<version>/licensed-<version>-<os>-x64.tar.gz > licensed.tar.gz
$> tar -xzf licensed.tar.gz
$> rm -f licensed.tar.gz
$> ./licensed list
```

For system wide usage, install licensed to a location on `$PATH`, e.g. `/usr/local/bin`.

## Usage

### Available commands

See the [commands documentation](./docs/commands) for documentation on available commands, or run `licensed -h` to see all of the current available commands.

### Configuration options

A configuration file is required for most commands.  See the [configuration file documentation](./docs/configuration.md) for more details on the configuration format and available configuration options.

### Available dependency sources

Licensed can enumerate dependency for many languages, package managers, and frameworks.  See the [sources documentation](./docs/sources) for the list of currently available sources.  Sources can be explicitly enabled and disabled as a [configuration option](./docs/configuration/sources.md).

### Automation

#### Bundler

The [bundler-licensed plugin](https://github.com/sergey-alekseev/bundler-licensed) runs `licensed cache` automatically when using `bundler`.  See the linked repo for usage and details.

#### GitHub Actions

The [licensed-ci](https://github.com/marketplace/actions/licensed-ci) GitHub Action runs `licensed` as part of an opinionated CI workflow and can be configured to run on any GitHub Action event.  See the linked actions for usage and details.

The [setup-licensed](https://github.com/marketplace/actions/setup-github-licensed) GitHub Action installs `licensed` to the workflow environment.  See the linked actions for usage and details.

## Development

To get started after checking out the repo, run

1. `script/bootstrap` to install dependencies
2. `script/setup` to setup test fixtures.
  - `script/setup -f` will force a clean test fixture environment
3. `script/cibuild` to run the tests

You can also run `script/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Adding a new source

See the [documentation on adding new sources](./docs/adding_a_new_source.md) for detailed information on what's required to add a new dependency source enumerator.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/github/licensed. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org/) code of conduct.  See [CONTRIBUTING](CONTRIBUTING.md) for more details.

## Disclaimer

Licensed is **not** a complete open source license compliance solution. Like any bug, licensing issues are far cheaper to fix if found early. Licensed is intended to provide automation around documenting the licenses of dependencies and whether they  are configured to be allowed by a user of licensed, in other words, to surface the most obvious licensing issues early.

Licensed is not a substitute for human review of each dependency for licensing or any other issues. It is not the goal of Licensed or GitHub, Inc. to provide legal advice about licensing or any other issues. If you have any questions regarding licensing compliance for your code or any other legal issues relating to it, it’s up to you to do further research or consult with a professional.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
