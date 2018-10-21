# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## 1.4.0 - 2018-10-20
### Added
- Git Submodules dependency source :tada:
- Configuration option to explicitly set a root absolute path

### Changes
- `COPYING` file is no longer matched as a legal file

### Fixed
- NPM source will enumerate multiple versions of the same dependency
- Running Licensed outside of a Git repository no longer raises an error
- Packaging scripts will correctly return to the previous branch when the script is finished

## 1.3.4 - 2018-09-20
### Changes
- Bundler source will avoid looking for a gemspec file when possible

## 1.3.3 - 2018-09-07
### Fixed
- Manifest source configuration globs correctly enumerates files from within submodules
- The manifest source no longer errors when getting version information from submodules

## 1.3.2 - 2018-08-15
### Fixed
- Fixed issue when multiple versions of a cabal package are found

## 1.3.1 - 2018-08-01
### Fixed
- Fixed regression finding ruby gems by path

## 1.3.0 - 2018-07-25
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

## 1.2.0 - 2018-06-22
### Added
- Building and packaging distributable exes for licensed releases
- Can now configure which Gemfile groups are excluded from dependency enumeration

### Fixed
- Bundler is no longer always reported as a dependency
- Set the minimum required ruby version for licensed

## 1.1.0 - 2018-06-04
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

## 1.0.1 - 2018-04-26
### Added
- GOPATH settable in configuration file

### Changed
- Reuse "license" metadata property when license text has not changed

### Fixed
- Path expansion for cabal "ghc_package_db" configuration setting occurs from repository root
- Local Gemfile(.lock) files correctly used in enumerating Bundler source dependencies

## 1.0.0 - 2018-02-20

Initial release :tada:

[Unreleased]: https://github.com/github/licensed/compare/1.4.0...HEAD
