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

When enumerating dependencies, `licensed` requires a path to find a license file as well as a couple of properties.
We also suggest a few optional properties that can make reviewing your cached dependency information easier.

#### Finding a license file

`Licensed::Dependency#initialize` accepts a path argument which is used by [`Licensee`](https://github.com/benbalter/licensee) to find a license
file for the dependency.  The path can be either a directory that contains the license file or the path to the file itself.

In some cases the license file will be in a parent directory of the specified location.  This can happen for instance with Golang packages
that share a license file, e.g. `github.com/go/pkg/1` and `github.com/go/pkg/2` might share a license at `github.com/go/pkg`.  In this case, license dependencies will accept an additional `search_root` optional property that denotes the root of the directory hierarchy that should be searched.  Directories will be examined in order from the given license location to the `search_root` location to prefer license files with more specificity, i.e. `github.com/go/pkg/1` will be searched before `github.com/go/pkg`.

#### Required properties

1. name
   - The name of the dependency.
2. version
   - The current version of the dependency, used to determine when a dependency has changed.

Together the name and the version should identify a unique dependency package that is used in a project.

#### Optional properties

1. summary
   - A short description of the dependencies purpose.
2. homepage
   - The dependency's homepage.
3. search_root
   - The root of the directory hierarchy to search for a license file.
4. Any other information that you find useful for reviewing or auditing dependencies.
