# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## 3.1.0

2021-06-16

### Added

- Licensed supports Swift/Swift package manager as a dependency source (:tada: @mattt https://github.com/github/licensed/pull/363)'

### Changed

- The `source_path` configuration property accepts arrays of inclusion and exclusion glob patterns (https://github.com/github/licensed/pull/368)
- The Nuget source now uses configured fallback folders to find dependencies that are not in found in the project folder (https://github.com/github/licensed/pull/366)
- The Nuget source supports a configurable property for the path from the project source path to the project's `obj` folder (https://github.com/github/licensed/pull/365)

### Fixed
- The Go source's checks for local packages will correctly find paths in case-insensitive file systems (https://github.com/github/licensed/pull/370)
- The Bundler source will no longer unnecessarily reset the local Bundler environment configuration (https://github.com/github/licensed/pull/372)

## 3.0.1

2021-05-17

### Fixed

- The bundler source will correctly enumerate dependencies pulled with a `git:` directive (https://github.com/github/licensed/pull/360)

## 3.0.0

2021-04-27

**This is a major release and includes potentially breaking changes to bundler dependency enumeration.**

### Changed

- The bundler source will return an error when run from an executable.  Please install licensed as a gem to continue using the bundler source.  Please see the [v3 migration document](./docs/migrations/v3.md) for full details and migration strategies.

## 2.15.2

2021-04-06

### Fixed

- The pip source works with package names containing periods (:tada: @bcskda https://github.com/github/licensed/pull/350)

## 2.15.1

2021-03-29

### Changed

- The npm source will ignore dependencies that are marked as both extraneous and missing (https://github.com/github/licensed/pull/347)

## 2.15.0
2021-03-24

### Added
- Support for npm 7 (https://github.com/github/licensed/pull/341)

### Fixed
- Files in the manifest source will be found correctly for apps that are not at the repository root (https://github.com/github/licensed/pull/345)

## 2.14.4
2021-02-09

### Added
- `list` and `cache` commands optionally print output in JSON or YML formats using the `--format/-f` flag (https://github.com/github/licensed/pull/334)
- `list` command will include detected license keys using the `--licenses/-l` flag (https://github.com/github/licensed/pull/334)

## 2.14.3
2020-12-11

### Fixed
- Auto-generating license text for a known license will no longer raise an error if the found license has no text (:tada: @Eun https://github.com/github/licensed/pull/328)

## 2.14.2
2020-11-20

### Fixed
- Yarn source correctly finds dependency paths on disk (https://github.com/github/licensed/pull/326)
- Go source better handles finding dependencies that have been vendored (https://github.com/github/licensed/pull/323)

## 2.14.1
2020-10-09

### Fixed
- Shell command output is encoded to UTF8 (https://github.com/github/licensed/pull/319)

## 2.14.0
2020-10-04

### Added
- `reviewed` dependencies can use glob pattern matching (https://github.com/github/licensed/pull/313)

### Fixed
- Fix configuring source path globs that expand into a single directory (https://github.com/github/licensed/pull/312)

## 2.13.0
2020-09-23

### Added
- `status` command results can be output in YAML and JSON formats (:tada: @julianvilas https://github.com/github/licensed/pull/303)

### Fixed
- `licensed` no longer crashes when parsing invalid YAML from cached records (https://github.com/github/licensed/pull/306)
- NPM source will no longer crash when invalid JSON is returned from npm CLI calls (https://github.com/github/licensed/pull/300)
- Bundler source is fixed to work properly with `gems.rb` lockfiles (https://github.com/github/licensed/pull/299)

## 2.12.2
2020-07-07

### Changed
- Cleaned up ruby 2.7 warnings (:tada: @jurre https://github.com/github/licensed/pull/292)
- Cleaned up additional warnings in tests (https://github.com/github/licensed/pull/293)

## 2.12.1
2020-06-30

### Fixed
- `licensed` no longer exits an error code when using the `--sources` CLI argument (https://github.com/github/licensed/pull/290)

## 2.12.0
2020-06-19

### Added
- `--sources` argument for cache, list, status and notices commands to filter running sources (https://github.com/github/licensed/pull/287)

### Fixed
- `cache` command will not remove files outside of enabled source cache paths (https://github.com/github/licensed/pull/287)

## 2.11.1
2020-06-09

### Fixed
- `notices` command properly reads cached dependency notices contents (https://github.com/github/licensed/pull/283)

## 2.11.0
2020-06-02

### Added
- `notices` command to create a `NOTICE` file for each configured app (https://github.com/github/licensed/pull/277)

### Fixed
- NuGet source no longer crashes on a non-existent dependency path (https://github.com/github/licensed/pull/280)
- Go source no longer crashes on a non-existent dependency package path (https://github.com/github/licensed/pull/274)

## 2.10.0
2020-05-15

### Changed
- NPM source ignores missing peer dependencies (https://github.com/github/licensed/pull/267)

### Added
- NuGet source (:tada: @zarenner https://github.com/github/licensed/pull/261)
- Multiple apps can share a single cache location (https://github.com/github/licensed/pull/263)

## 2.9.2
2020-04-28

### Changed
- `licensee` minimum version bumped to 9.13.2 (https://github.com/github/licensed/pull/256)

## 2.9.1
2020-03-24

### Changed
- relaxed gem version restrictions on Thor (:tada: @eileencodes https://github.com/github/licensed/pull/254)

## 2.9.0
2020-03-19

### Added
- Source paths use glob pattern matching (https://github.com/github/licensed/pull/245)

### Fixed
- Mix source supports updates to mix.lock format (:tada: @bruce https://github.com/github/licensed/pull/242)
- Go source supports `go list` format changes in go 1.14 (https://github.com/github/licensed/pull/247)

### Changed
- `licensed cache` will flag dependencies for re-review when license text changes (https://github.com/github/licensed/pull/248)
- `licensed status` will raise errors on dependencies that need re-review (https://github.com/github/licensed/pull/248)
- `licensee` minimum version bumped to 9.13.1 (https://github.com/github/licensed/pull/251)

## 2.8.0
2020-01-03

### Added
- Yarn source (https://github.com/github/licensed/pull/232, https://github.com/github/licensed/pull/233, https://github.com/github/licensed/pull/236)
- NPM source has a new option to include non-production dependencies (https://github.com/github/licensed/pull/231)

### Fixed
- Cabal source will no longer crash if packages aren't found (https://github.com/github/licensed/pull/230)

## 2.7.0
2019-11-10

### Added
- License text is automatically generated for known licenses when not otherwise available (https://github.com/github/licensed/pull/223)

### Changed
- Ignoring dependencies uses glob pattern matching (https://github.com/github/licensed/pull/225)

## 2.6.2
2019-11-03

### Changed
- A number of improvements to the go dependency enumerator
  - use `go env GOPATH` as a default if no other GOPATH is found
  - better compatibility with go modules when finding license content
  - better compatibility with vendored go modules
  - use a packages godoc.org page as it's homepage
  - better checks for standard packages, reducing the amount of cached content

## 2.6.1
2019-10-26

### Changed
- Performance improvements during dependency enumeration (:tada: @krzysztof-pawlik-gat https://github.com/github/licensed/pull/204, https://github.com/github/licensed/pull/207) (https://github.com/github/licensed/pull/210)

## 2.6.0
2019-10-22

### Added
- Mix source for Elixir (:tada: @bruce https://github.com/github/licensed/pull/195)

## 2.5.0
2019-09-26

### Added
- `env` command to output application environment configuration (https://github.com/github/licensed/pull/187, https://github.com/github/licensed/pull/191)

### Changed
- `status` command will pass if multiple allowed licenses are found (https://github.com/github/licensed/pull/188)

## 2.4.0
2019-09-15

### Added
- Composer source for PHP (https://github.com/github/licensed/pull/182)

## 2.3.2
2019-08-26

### Fixed
- Bundler with/without array settings are properly handled for bundler 1.15.x

## 2.3.1
2019-08-20

### Changed
- Using the npm source with yarn, "missing" dependencies are no longer considered errors (:tada: @krzysztof-pawlik-gat https://github.com/github/licensed/pull/170)
- The bundler source now calls `gem specification` with dependency version requirements (https://github.com/github/licensed/pull/173)

## 2.3.0
2019-05-19

### Added
- New Pipenv dependency source enumerator (:tada: @krzysztof-pawlik-gat https://github.com/github/licensed/pull/167)

## 2.2.0
2019-05-11

### Added
- Content hash versioning strategy for go and manifest sources (https://github.com/github/licensed/pull/164)

### Fixed
- Python source handles urls and package names with "-" in requirements.txt (:tada: @krzysztof-pawlik-gat https://github.com/github/licensed/pull/165)

## 2.1.0
2019-04-16

### Added
- New Gradle dependency source enumerator (:tada: @dbussink https://github.com/github/licensed/pull/150, @jandersson-svt https://github.com/github/licensed/pull/159)
- Metadata added to distributed packages (https://github.com/github/licensed/pull/160)

### Changes
- Bundler dependency source loads license key from a gem's cached gemspec file as a fallback (https://github.com/github/licensed/pull/154)
- Licensed will only raise errors on an empty dependency path when caching records (https://github.com/github/licensed/pull/149)

### Fixed
- Migrating to v2 will no longer crash trying to migrate cached records that don't exist (https://github.com/github/licensed/pull/148)
- Reported warnings will no longer crash licensed when caching records (https://github.com/github/licensed/pull/147)

## 2.0.1
2019-02-14

### Changes
- Dependency paths that don't exist on the local disk are reported as warnings
- Cache, status and list output is sorted by app name, source type and dependency name
- Bumped `licensee` gem requirement

## 2.0.0
2019-02-09

**This is a major release and includes breaking changes to the configuration and cached record file formats**

### Added
- New `migrate` command to automatically update configuration and cached record file formats
- New extensible reporting infrastructure
- New base command and source classes to abstract away implementation details

### Changes
- Cached dependency metadata files are now stored entirely as YAML, with `.dep.yml` extension
- The Bundler dependency source is now identified in configuration files and output as `bundler` instead of `rubygem`
- Refactored sources for better consistency between classes
- Refactored commands for better consistency between classes
- Command outputs have changed for better consistency
- Updated Dependency classes for better integration with `licensee`

### Fixed
- Licensed no longer exits on errors when evaluating dependency sources or finding dependencies
- The Bundler dependency source correctly finds the `bundler` gem as a dependency in more cases

## 1.5.2
2018-12-27

### Changes
- Go source added support for Go modules and Golang 1.11+ (https://github.com/github/licensed/pull/113)

### Fixed
- Licensed will have a non-zero exit code when commands fail (:tada: @parkr https://github.com/github/licensed/pull/111)

## 1.5.1
2018-10-30

### Fixed
- Fixed a scenario where licensed wasn't finding bundler dependencies when run as an executable due to a ruby version mismatch (https://github.com/github/licensed/pull/106)

## 1.5.0
2018-10-24

### Added
- `licensed (version | -v | --version)` command to see the current licensed version (:tada: @mwagz! https://github.com/github/licensed/pull/101)

### Fixed
- NPM source no longer raises an error when ignored dependencies aren't found (:tada: @mwagz! https://github.com/github/licensed/pull/100)
- Checking for a Git repo will no longer possibly modify `.git/index` (:tada: @dbussink https://github.com/github/licensed/pull/102)
- Fixed a scenario where licensed wasn't finding bundler dependencies when run as an executable (https://github.com/github/licensed/pull/103)

## 1.4.0
2018-10-20

### Added
- Git Submodules dependency source :tada:
- Configuration option to explicitly set a root absolute path

### Changes
- `COPYING` file is no longer matched as a legal file

### Fixed
- NPM source will enumerate multiple versions of the same dependency
- Running Licensed outside of a Git repository no longer raises an error
- Packaging scripts will correctly return to the previous branch when the script is finished

## 1.3.4
2018-09-20

### Changes
- Bundler source will avoid looking for a gemspec file when possible

## 1.3.3
2018-09-07

### Fixed
- Manifest source configuration globs correctly enumerates files from within submodules
- The manifest source no longer errors when getting version information from submodules

## 1.3.2
2018-08-15

### Fixed
- Fixed issue when multiple versions of a cabal package are found

## 1.3.1
2018-08-01

### Fixed
- Fixed regression finding ruby gems by path

## 1.3.0
2018-07-25

### Added
- Manifests for the manifest dependency source can be specified using glob patterns in the configuration
- Paths to licenses for dependencies from the manifest dependency source can be specified in the configuration
- Manifest dependency source looks for license content in C-style comments if a license file isn't found

## Changes
- GitHub is no longer queried to find remote license information
- Removed custom logic around determining whether to use the license key from `licensee`
- NPM dependency enumeration doesn't use `npm list`
- Licensed now tracks content from multiple license files when available

### Fixed
- Fixed regression finding platform-specific ruby gems

## 1.2.0
2018-06-22

### Added
- Building and packaging distributable exes for licensed releases
- Can now configure which Gemfile groups are excluded from dependency enumeration

### Fixed
- Bundler is no longer always reported as a dependency
- Set the minimum required ruby version for licensed

## 1.1.0
2018-06-04

### Added
- Pip dependency source :tada:
- Go Dep dependency source :tada:

### Changed
- Changed how `sources` configuration property affects which sources are enabled
- Raise informative error messages when shell commands fail

### Fixed
- Don't reuse cached license when cached version metadata is missing
- Disable dependency sources when dependent tools are not available
- Vendored packages from the go std library are properly excluded
- Cabal dependency enumeration properly includes executable targets

## 1.0.1
2018-04-26

### Added
- GOPATH settable in configuration file

### Changed
- Reuse "license" metadata property when license text has not changed

### Fixed
- Path expansion for cabal "ghc_package_db" configuration setting occurs from repository root
- Local Gemfile(.lock) files correctly used in enumerating Bundler source dependencies

## 1.0.0
2018-02-20

Initial release :tada:

[Unreleased]: https://github.com/github/licensed/compare/3.1.0...HEAD
