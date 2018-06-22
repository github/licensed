# Packaging licensed for distribution

Licensed is built into executables and packaged for distribution using [ruby-packer][ruby-packer].

Executable packages are currently supported for:
1. Linux
2. MacOS / Darwin

The packaged executables contain a self-expanding file system containing ruby, licensed and all of it's runtime dependencies.  Licensed is run inside the contained file system, allowing usage in scenarios where ruby is not available on the host system.

### Building packages

Packages are built as `licensed-$VERSION-$PLATFORM-x64.tar.gz` tarballs that contain a single `./licensed` executable.  After building a package through the available scripting, it will be available in the `pkg` directory.

By default an exe is built for the current licensed git `HEAD`.  The
`$VERSION` in the package name will be set to the current branch name if
available, otherwise the current SHA.  To use a specific licensed version,
set a `VERSION` environment variable when calling the packaging scripts.  `VERSION` can be set to any value that works with `git checkout`.

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
$ bundle exec rake package:linux
```

#### Building packages for a specific version
```bash
# VERSION can be set to anything that works with git checkout - tag, branch, SHA1
$ VERSION="1.1.0" script/package
```
or
```bash
# VERSION can be set to anything that works with git checkout - tag, branch, SHA1
$ VERSION="1.1.0" bundle exec rake package
```

[ruby-packer]: https://github.com/pmq20/ruby-packer
