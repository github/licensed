# Adding a new source dependency enumerator

## Implement new `Source` class

Dependency enumerators inherit and override the [`Licensed::Sources::Source`](../lib/licensed/sources/source.rb) class.

#### Required method overrides
1. `Licensed::Sources::Source#enabled?`
   - Returns whether dependencies can be enumerated in the current environment.
2. `Licensed::Sources::Source#enumerate_dependencies`
   - Returns an enumeration of `Licensed::Dependency` objects found which map to the dependencies of the current project.

#### Optional method overrides
1. `Licensed::Sources::Source.type`
   - Returns the name of the current dependency enumerator as it is found in a licensed configuration file.

## Determining if dependencies should be enumerated

This section covers the `Licensed::Sources::Source#enabled?` method.  This method should return a truthy/falsey value indicating
whether `Licensed::Source::Sources#enumerate_dependencies` should be called on the current dependency source object.

Determining whether dependencies should be enumerated depends on whether all the tools or files needed to find dependencies are present.
For example, to enumerate `npm` dependencies the `npm` CLI tool must be reachable and a `package.json` file needs to exist in the licensed app's configured [`source_path`](./configuration.md#configuration-paths).

## Enumerating dependencies

This section covers the `Licensed::Sources::Source#enumerate_dependencies` method.  This method should return an enumeration of
`Licensed::Dependency` objects.

Enumerating dependencies will require some knowledge of the package manager, language or framework that manages the dependencies.

Relying on external tools always has a risk that the tool could change.  It's generally preferred to not rely on package manager files
or other implementation details as these could change over time.  CLI tools that provides the necessary information are generally preferred
as they will more likely have requirements for backwards compatibility.

#### Creating dependency objects

Creating a new `Licensed::Dependency` object requires name, version, and path arguments.  Dependency objects optionally accept a path to use as search root when finding licenses along with any other metadata that is useful to identify the dependency.

##### `Licensed::Dependency` arguments

1. name (required)
   - The name of the dependency. Together with the version, this should uniquely identify the dependency.
2. version (required)
   - The current version of the dependency, used to determine when a dependency has changed. Together with the name, this should uniquely identify the dependency.
3. path (required)
   - A path used by [`Licensee`](https://github.com/benbalter/licensee) to find dependency license content.  Can be either a folder or a file.
4. search_root (optional)
   - The root of the directory hierarchy to search for a license file.
5. metadata (optional)
   - Any additional metadata that would be useful in identifying the dependency.
   - suggested metadata
      1. summary
         - A short description of the dependencies purpose.
      2. homepage
         - The dependency's homepage.

#### Finding licenses

In some cases, license content will be in a parent directory of the specified location.  For instance, this can happen with Golang packages
that share a license file, e.g. `github.com/go/pkg/1` and `github.com/go/pkg/2` might share a license at `github.com/go/pkg`.  In this case, create a `Licensed::Dependency` with the optional `search_root` property, which denotes the root of the directory hierarchy that should be searched.  Directories will be examined in order from the given license location to the `search_root` location to prefer license files with more specificity, i.e. `github.com/go/pkg/1` will be searched before `github.com/go/pkg`.
