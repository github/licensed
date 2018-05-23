# Bundler (rubygem)

The bundler source will detect dependencies `Gemfile` and `Gemfile.lock` files are found at an apps `source_path`.  The source uses the `Bundler` API to enumerate dependencies from `Gemfile` and `Gemfile.lock`.

The bundler source will exclude gems in the `:development` and `:test` groups.  Be aware that if you have a local
bundler configuration (e.g. `.bundle`), that configuration will be respected as well.  For example, if you have a local
configuration set for `without: [':server']`, the bundler source will exclude all gems in the `:server` group.
