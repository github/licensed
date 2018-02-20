# Go

The go source uses `go` CLI commands to enumerate dependencies and properties.  It is expected that `go` projects have been built, and that `GO_PATH` and `GO_ROOT` are properly set before running `licensed`.

Source paths for go projects should point to a location that contains an entrypoint to the executable or library.

An example usage might see a configuration like:
```YAML
source_path: go/path/src/github.com/BurntSushi/toml/cmd/tomlv
```

Note that this configuration points directly to the tomlv command source, which contains `func main`.
