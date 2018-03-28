# Go

The go source uses `go` CLI commands to enumerate dependencies and properties.  It is expected that `go` projects have been built, and that `go` environment variables are properly set before running `licensed`.

#### Source paths
Source paths for go projects should point to a location that contains an entrypoint to the executable or library.

An example usage might see a configuration like:
```YAML
source_path: go/path/src/github.com/BurntSushi/toml/cmd/tomlv
```

Note that this configuration points directly to the tomlv command source, which contains `func main`.

#### GOPATH
A valid `GOPATH` is required to successfully find `go` dependencies.  If `GOPATH` is not available in the calling environment, or if a different `GOPATH` is needed than what is set in the calling environment, a value can be set in the `licensed` configuration file.

```yaml
go:
  GOPATH: ~/go
```

The setting supports absolute, relative and expandable (e.g. "~") paths.  Relative paths are considered relative to the repository root.

Non-empty `GOPATH` configuration settings will override the `GOPATH` environment variable while enumerating `go` dependencies.  The `GOPATH` environment variable is restored once dependencies have been enumerated.
