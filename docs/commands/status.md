# `licensed status`

The status command finds all dependencies and checks whether each dependency has a valid cached record.

A dependency will fail the status checks if:

1. No cached record is found
2. The cached record's version is different than the current dependency's version
3. The cached record's `licenses` data is empty
4. The cached record's `license` metadata doesn't match an `allowed` license from the dependency's application configuration.
   - If `license: other` is specified and all of the `licenses` entries match an `allowed` license a failure will not be logged
5. The cached record is flagged for re-review.
   - This occurs when the record's license text has changed since the record was reviewed.

## Options

- `--config`/`-c`: the path to the licensed configuration file
   - default value: `./.licensed.yml`
- `--sources`/`-s`: runtime filter on which dependency sources are run.  Sources must also be enabled in the licensed configuration file.
   - default value: not set, all configured sources
- `--format`/`-f`: the output format
   - default value: `yaml`
- `--force`: if set, forces all dependency metadata files to be recached
   - default value: not set

## Reported Data

The following data is reported for each dependency when the YAML or JSON report formats are used

- name: the licensed recognized name for the dependency including the app and source name
   - e.g. the full name for the `thor` bundler dependency used by this tool is `licensed.bundler.thor`
- allowed: true if the dependency has passed all checks, false otherwise
- version: the version of the enumerated dependency
- license: the dependency's SPDX license identifier
- filename: the full path on disk to the dependency's cached metadata file, if available
- errors: any error messages from failed status checks, if available
