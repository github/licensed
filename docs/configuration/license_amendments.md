# License amendments

The `amendments` configuration file option is used to specify paths to files containing content which amends the license that would normally applies to a library used by an application.  File contents are expected to be plain text

Amendment files can be located anywhere on disk that is accessible to licensed.  File paths can be specified as a string or array and can contain glob values to simplify configuration inputs.  All file paths are evaluated from the [configuration root](./configuration_root.md).

## Examples

### With a string

```yaml
amendments:
  # specify the type of dependency
  bundler:
    # specify the dependency name and path to an amendment file
    <gem-name>: .licenses/amendments/bundler/<gem-name>/amendment.txt
```

### With a glob string

```yaml
amendments:
  # specify the type of dependency
  bundler:
    # specify the dependency name and one or more amendment files with a glob pattern
    <gem-name>: .licenses/amendments/bundler/<gem-name>/*.txt
```

### With an array of strings

```yaml
amendments:
  # specify the type of dependency
  bundler:
    # specify the dependency name and array of paths to amendment files
    <gem-name>:
      - .licenses/amendments/bundler/<gem-name>/amendment-1.txt
      - .licenses/amendments/bundler/<gem-name>/amendment-2.txt
```
