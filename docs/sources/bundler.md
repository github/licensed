# Bundler (rubygem)

The bundler source will detect dependencies `Gemfile` and `Gemfile.lock` files are found at an apps `source_path`.  The source uses the `Bundler` API to enumerate dependencies from `Gemfile` and `Gemfile.lock`.

### Excluding gem groups

The bundler source determines which gem groups to include or exclude with the following logic, in order of precedence.
1. Include all groups specified in the Gemfile
2. Exclude all groups from the `without` bundler configuration (e.g. `.bundle/config`)
3. Include all groups from the `with` bundler configuration (e.g. `.bundle/config`)
4. Exclude all groups from the `without` licensed configuration (`:development` and `:test` if not otherwise specified)

`licensed` can be configured to override the default "without" development and test groups in the configuration file.

Strings and string arrays are both :+1:

```yml
rubygem:
  without: development
```

or

```yml
rubygem:
  without:
    - build
    - development
    - test
```

### Specifying a custom bundler executable

A custom bundler executable can be specified in the `licensed` configuration file.  The path can be set as
- an absolute path
- an expandable path with special characters (e.g. `~`)
- a path relative to the configured root absolute path

```yml
rubygem:
  bundler_exe: "bin/bundle"
```
