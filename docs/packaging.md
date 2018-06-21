# Packaging licensed for distribution

Licensed is built into executables and packaged for distribution using [ruby-packer][ruby-packer].

Executable packages are currently supported for:
1. Linux
2. MacOS / Darwin

The packaged executables contain a self-expanding file system containing ruby, licensed and all of it's runtime dependencies.  Licensed is run inside the contained file system, allowing usage in scenarios where ruby is not available on the host system.

### Building packages

Packages are built as `licensed-$VERSION-$PLATFORM-x64.tar.gz` tarballs that contain a single `./licensed` executable.  After building a package through the available scripting, it will be available in the `pkg` directory.

#### Building all packages
```bash
# build all packages
$ script/package
```
or
```bash
# build all packages
$ bundle exec rake package
```

#### Building packages for a single platform
```bash
# build package for linux
$ script/package linux
```
or
```bash
# build package for linux
$ bundle exec rake package[linux]

# if using the zsh shell then you'll need to escape the brackets
$ bundle exec rake package\[linux\]
```

[ruby-packer]: https://github.com/pmq20/ruby-packer
