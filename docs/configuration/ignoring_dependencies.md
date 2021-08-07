# Ignoring dependencies

**Key**: ignored
**Default value**: none

This configuration property is used to fully ignore a dependency during all `licensed` commands.  Any dependency on this list will not
be enumerated, or have its metadata cached or checked for compliance.  This is intended for dependencies that do not require attribution
or compliance checking - internal or 1st party dependencies, or dependencies that do not ship with the product such as test frameworks.

The ignored dependency list is organized based on the dependency source type - `bundler`, `go`, etc.  Add a dependency's metadata identifier to the appropriate source type sub-property to cause `licensed` to no longer take action on the dependency.  Glob patterns can be used to identify multiple internal dependencies without having to manage a large list.

```yml
ignored:
  bundler:
    - my-internal-gem
    - my-first-party-gem
  go:
    - github.com/me/my-repo/**/*
```
