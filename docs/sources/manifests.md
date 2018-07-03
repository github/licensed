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

### Finding license content from source file comments

When a file containing license content is not found for a group of source files,
Licensed will attempt to parse license text from source file comments.

There are some limitations on this functionality:

1. Comments MUST contain a copyright statement
2. Comments MUST be C-style multiline comments, e.g. `/* comment */`
3. Comments SHOULD contain identical indentation for each content line.

The following examples are all :+1:.  Licensed will try to preserve formatting,
however for best results comments should not mix tabs and spaces in leading whitespace.
```
/*
   <copyright statement>

   <license text>
 */

/* <copyright statement>
   <license text>
 */

/*
 * <copyright statement>
 * <license text>
 *
 * <license text>
 */
```
