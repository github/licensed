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
For example, to enumerate `npm` dependencies the `npm` CLI tool must be found with `Licensed::Shell.tool_available?` and a `package.json` file needs to exist in the licensed app's configured [`source_path`](./configuration.md#configuration-paths).

#### Gating functionality when required tools are not available.

When adding new dependency sources, ensure that `script/bootstrap` scripting and tests are only run if the required tooling is available on the development machine.

* See `script/bootstrap` for examples of gating scripting based on whether tooling executables are found.
* Use `Licensed::Shell.tool_available?` when writing test files to gate running a test suite when tooling executables aren't available.
```ruby
if Licensed::Shell.tool_available?('bundle')
  describe Licensed::Source::Bundler do
    ...
  end
end
```

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
6. errors (optional)
  - Any errors found when loading dependency information.

##### Creating specialized Dependency objects

`Licensed::Dependency` objects inherit from `Licensee::Projects::FsProject` and can override or extend the default `Licensee` behavior to find files for a dependency.

If a dependency source requires customized logic when finding or loading license or legal content, the source should define and use a `Licensed::Dependency` subclass to implement the required logic.

For examples of this see:

- [Manifest::Dependency](../../lib/licensed/sources/manifest.rb) which finds license text from C-style comments
- [Gradle::Dependency](../../lib/licensed/sources/gradle.rb) which loads license text from a URI

#### Finding licenses

In some cases, license content will be in a parent directory of the specified location.  For instance, this can happen with Golang packages
that share a license file, e.g. `github.com/go/pkg/1` and `github.com/go/pkg/2` might share a license at `github.com/go/pkg`.  In this case, create a `Licensed::Dependency` with the optional `search_root` property, which denotes the root of the directory hierarchy that should be searched.  Directories will be examined in order from the given license location to the `search_root` location to prefer license files with more specificity, i.e. `github.com/go/pkg/1` will be searched before `github.com/go/pkg`.

#### Handling errors when enumerating dependencies

External tools have their own error handling which, if left unhandled, can cause dependency enumeration as a whole to fail either for an individual dependency source or for licensed as a whole.  These errors should be gracefully handled to allow for the best possible user experience.

##### Handling errors related to a specific dependency

`Licensed::Dependency#initialize` will already set errors related to `nil` or empty `path:` arguments, as well as paths that don't exist.  Additional errors can be set to a dependency using the `errors:` argument, e.g. `Licensed::Dependency.new(errors: ["error"])`.

When a dependency contains errors, all errors will be reported to the user and `Licensed::Command::Command#evaluate_dependency` will be not be called.

##### Handling errors related to source evaluation

When an error occurs related to a specific source, raise a `Licensed::Sources::Source::Error` with an informative message.  The error will be caught and reported to the user, and further evaluation of the source will be halted.

As an example, this could be useful if a source is enabled but incorrectly configured.
