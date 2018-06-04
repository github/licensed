# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/github/licensed/compare/v1.0.1...HEAD
