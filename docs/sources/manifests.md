# Manifests

The manifest source can be used when no package managers are available.

Manifest files are used to match source files with their corresponding packages to find package dependencies.  Manifest file paths can be specified in the app configuration with the following setting:
```yml
manifest:
  path: 'path/to/manifest.json'
```

If a manifest path is not specified for an app, the file will be looked for at the apps `<cache_path>/manifest.json`.

The manifest can be a JSON or YAML file with a single root object and properties mapping file paths to package names.
```JSON
{
  "file1": "package1",
  "path/to/file2": "package1",
  "other/file3": "package2"
}
```

File paths are relative to the git repository root.  Package names will be used for the metadata file names at `path/to/cache/manifest/<package>.txt`

If multiple source files map to a single package and they share a common path under the git repository root, that directory will be used to find license information, if available.

It is the responsibility of the repository owner to maintain the manifest file.
