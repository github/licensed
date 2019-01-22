# Bundler

The bundler source will detect dependencies `Gemfile` and `Gemfile.lock` files are found at an apps `source_path`.  The source uses the `Bundler` API to enumerate dependencies from `Gemfile` and `Gemfile.lock`.

### Enumerating bundler dependencies when using the licensed executable

**Note** this content only applies to running licensed from an executable.  It does not apply when using licensed as a gem.

_It is required that the ruby runtime is available when running the licensed executable._

The licensed executable contains and runs a version of ruby.  When using the Bundler APIs, a mismatch between the version of ruby built into the licensed executable and the version of licensed used during `bundle install` can occur.  This mismatch can lead to licensed raising errors due to not finding dependencies.

For example, if `bundle install` was run with ruby 2.5.0 then the bundler specification path would be `<bundle path>/ruby/2.5.0/specifications`.  However, if the licensed executable contains ruby 2.4.0, then licensed will be looking for specifications at `<bundle path>/ruby/2.4.0/specifications`.  That path may not exist, or it may contain invalid or stale content.

To prevent confusion, licensed uses the local ruby runtime to determine the ruby version for local gems during `bundle install`.  If bundler is also available, then the ruby command will be run from a `bundle exec` context.

### Excluding gem groups

The bundler source determines which gem groups to include or exclude with the following logic, in order of precedence.
1. Include all groups specified in the Gemfile
2. Exclude all groups from the `without` bundler configuration (e.g. `.bundle/config`)
3. Include all groups from the `with` bundler configuration (e.g. `.bundle/config`)
4. Exclude all groups from the `without` licensed configuration (`:development` and `:test` if not otherwise specified)

`licensed` can be configured to override the default "without" development and test groups in the configuration file.

Strings and string arrays are both :+1:

```yml
bundler:
  without: development
```

or

```yml
bundler:
  without:
    - build
    - development
    - test
```
