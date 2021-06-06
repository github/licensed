# Configuration file

A configuration file specifies the details of enumerating and operating on license metadata for apps.

Configuration can be specified in either YML or JSON formats.  Examples below are given in YML.

## Configuration Paths

`licensed` requires a path to enumerate dependencies at (`source_path`) and a path to store cached metadata (`cache_path`).

To determine these paths across multiple environments where absolute paths will differ, a known root path is needed to evaluate relative paths against.
In using a root, relative source and cache paths can be specified in the configuration file.

When using a configuration file, the root property can be set as either a path that can be expanded from the configuration file directory using `File.expand_path`, or the value `true` to use the configuration file directory as the root.

When creating a `Licensed::Dependency` manually with a `root` property, the property must be an absolute path - no path expansion will occur.

If a root path is not specified, it will default to using the following, in order of precedence
1. the root of the local git repository, if run inside a git repository
2. the current directory

### Source paths

A source path is the directory in which licensed should run to enumerate dependencies.  This is often dependent on the project type, for example the bundler source should be run from the directory containing a `Gemfile` or `gems.rb` while the go source should be run from the directory containing an entrypoint function.

#### Using glob patterns

The `source_path` property can use one or more glob patterns to share configuration properties across multiple application entrypoints.

For example, there is a common pattern in Go projects to include multiple executable entrypoints under folders in `cmd`.  Using a glob pattern allows users to avoid manually configuring and maintaining multiple licensed application `source_path`s.  Using a glob pattern will also ensure that any new entrypoints matching the pattern are automatically picked up by licensed commands as they are added.

```yml
sources:
  go: true

# treat all directories under `cmd` as separate apps
source_path: cmd/*
```

In order to better filter the results from glob patterns, the `source_path` property also accepts an array of inclusion and exclusion glob patterns similar to gitignore files.  Inclusion patterns will add matching directory paths to resulting set of source paths, while exclusion patterns will remove matching directory paths.

```yml
source_path:
  - "projects/*" # include by default all directories under "projects"
  - "!projects/*Test" # exclude all projects ending in "Test"
```

Glob patterns are syntactic sugar for, and provide the same functionality as, manually specifying multiple `source_path` values. See the instructions on [specifying multiple apps](./#specifying-multiple-apps) below for additional considerations when using multiple apps.

## Restricting sources

The `sources` configuration property specifies which sources `licensed` will use to enumerate dependencies.
By default, `licensed` will generally try to enumerate dependencies from all sources.  As a result,
the configuration property should be used to explicitly disable sources rather than to enable a particular source.

Be aware that this configuration is separate from an individual sources `#enabled?` method, which determines
whether the source is valid for the current project.  Even if a source is enabled in the configuration
it may still determine that it can't enumerate dependencies for a project.

```yml
sources:
  bower: true
  bundler: false
```

`licensed` determines which sources will try to enumerate dependencies based on the following rules:
1. If no sources are configured, all sources are enabled
2. If no sources are set to true, any unconfigured sources are enabled
```yml
sources:
  bower: false
  # all other sources are enabled by default since there are no sources set to true
```
3. If any sources are set to true, any unconfigured sources are disabled
```yml
sources:
  bower: true
  # all other sources are disabled by default because a source was set to true
```

## Applications

What is an "app"?  In the context of `licensed`, an app is a combination of a source path and a cache path.

Configuration can be set up for single or multiple applications in the same repo.  There are a number of settings available for each app:
```yml
# If not set, defaults to the directory name of `source_path`
name: 'My application'

# Path is relative to the location of the configuration file and specifies
# the root to expand all paths from
# If not set, defaults to a git repository root
root: 'relative/path/from/configuration/file/directory'

# Path is relative to configuration root and specifies where cached metadata will be stored.
# If not set, defaults to '.licenses'
cache_path: 'relative/path/to/cache'

# Path is relative to configuration root and specifies the working directory when enumerating dependencies
# Optional for single app configuration, required when specifying multiple apps
# Defaults to current directory when running `licensed`
source_path: 'relative/path/to/source'

# Sources of metadata
sources:
  bower: true
  bundler: false

# Dependencies with these licenses are allowed and will not raise errors or warnings.
# This list does not have a default value and is required for `licensed status`
# to succeed.
allowed:
  - mit
  - apache-2.0
  - bsd-2-clause
  - bsd-3-clause
  - cc0-1.0
  - isc

# These dependencies are ignored during enumeration.
# They will not be cached, and will not raise errors or warnings.
# This configuration is intended to be used for dependencies that don't need to
# be included for compliance purposes, such as other projects owned by the current
# project's owner, internal dependencies, and dependencies that aren't shipped with
# the project like test frameworks.
ignored:
  bundler:
    - some-internal-gem

  bower:
    - some-internal-package

# These dependencies have licenses not on the `allowed` list and have been reviewed.
# They will be cached and checked, but will not raise errors or warnings for a
# non-allowed license.  Dependencies on this list will still raise errors if
# license text cannot be found for the dependency.
reviewed:
  bundler:
    - bcrypt-ruby

  bower:
  - classlist # public domain
  - octicons
```

### Specifying a single app
To specify a single app, either include a single app with `source_path` in the `apps` configuration, or remove the `apps` setting entirely.

If the configuration does not contain an `apps` value, the root configuration will be used as an app definition.  In this scenario, the `source_path` is not a required value and will default to the directory that `licensed` was executed from.

If the configuration contains an `apps` value with a single app configuration, `source_path` must be specified.  Additionally, the applications inherited `cache_path` value will contain the application name.  See [Inherited cache_path values](#inherited_cache_path_values)

### Specifying multiple apps
The configuration file can specify multiple source paths to enumerate metadata, each with their own configuration.

Nearly all configuration settings can be inherited from root configuration to app configuration.  Only `source_path` is required to define an app.

Here are some examples:

#### Inheriting configuration
```yml
sources:
  go: true
  bundler: false

ignored:
  bundler:
    - some-internal-gem

reviewed:
  bundler:
    - bcrypt-ruby

cache_path: 'path/to/cache'
apps:
  - source_path: 'path/to/app1'
  - source_path: 'path/to/app2'
    sources:
      bundler: true
      go: false
```

In this example, two apps have been declared.  The first app, with `source_path` `path/to/app1`, inherits all configuration settings from the root configuration.  The second app, with `source_path` `path/to/app2`, overrides the `sources` configuration and inherits all other settings.

#### Default app names
An app will not inherit a name set from the root configuration.  If not provided, the `name` value will default to the directory name from `source_path`.
```yml
apps:
  - source_path: 'path/to/app1'
  - source_path: 'path/to/app2'
```

In this example, the apps have names of `app1` and `app2`, respectively.

#### Inherited cache_path values
When an app inherits a `cache_path` from the root configuration, it will automatically append it's name to the end of the path to separate it's metadata from other apps.  To force multiple apps to use the same path to cached metadata, explicitly set the `cache_path` value for each app.
```yml
cache_path: 'path/to/cache'
apps:
  - source_path: 'path/to/app1'
    name: 'app1'
  - source_path: 'path/to/app2'
    name: 'app2'
  - source_path: 'path/to/app3'
    name: 'app3'
    cache_path: 'path/to/app3/cache'
```

In this example `app1` and `app2` have `cache_path` values of `path/to/cache/app1` and `path/to/cache/app2`, respectively.  `app3` has an explicit path set to `path/to/app3/cache`

```yml
apps:
  - source_path: 'path/to/app1'
```

In this example, the root configuration will contain a default cache path of `.licenses`.  `app1` will inherit this value and append it's name, resulting in a cache path of `.licenses/app1`.

### Sharing caches between apps

Dependency caches can be shared between apps by setting the same cache path on each app.

```yaml
apps:
  - source_path: "path/to/app1"
    cache_path: ".licenses/apps"
  - source_path: "path/to/app2"
    cache_path: ".licenses/apps"
```

When using a source path with a glob pattern, the apps created from the glob pattern can share a dependency by setting an explicit cache path and setting `shared_cache` to true.

```yaml
source_path: "path/to/apps/*"
cache_path: ".licenses/apps"
shared_cache: true
```

## Source specific configuration

See the [source documentation](./sources) for details on any source specific configuration.
