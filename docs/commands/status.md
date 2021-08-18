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

## Status errors and resolutions

### cached dependency record not found

**Cause:** A dependency was found while running `licensed status` that does not have a corresponding cached metadata file
**Resolution:** Run `licensed cache` to update the metadata cache and create the missing metadata file

### cached dependency record out of date

**Cause:** A dependency was found while running `licensed status` with a different version than is contained in the dependency's cached metadata file
**Resolution:** Run `licensed cache` to update the out-of-date metadata files

### missing license text

**Cause:** A license determination was made, e.g. from package metadata, but no license text was found.
**Resolution:** Manually verify whether the dependency includes a file containing license text.  If the dependency code that was downloaded locally does not contain the license text, please check the dependency source at the version listed in the dependency's cached metadata file to see if there is license text that can be used.

If the dependency does not include license text but does specify that it uses a specific license, please copy the standard license text from a [well known source](https://opensource.org/licenses).

### license text has changed and needs re-review. if the new text is ok, remove the `review_changed_license` flag from the cached record

**Cause:** A dependency that is set as [reviewed] in the licensed configuration file has substantially changed and should be re-reviewed.
**Resolution:** Review the changes to the license text and classification, along with other metadata contained in the cached file for the dependency.  If the dependency is still allowable for use in your project, remove the `review_changed_license` key from the cached record file.

### license needs review

**Cause:** A dependency is using a license that is not in the configured [allowed list of licenses][allowed], and the dependency has not been marked [ignored] or [reviewed].
**Resolution:** Review the dependency's usage and specified license with someone familiar with OSS licensing and compliance rules to determine whether the dependency is allowable.  Some common resolutions:

1. The dependency's specified license text differed enough from the standard license text that it was not recognized and classified as `other`.  If, with human review, the license text is recognizable then update the `license: other` value in the cached metadata file to the correct license.
1. The dependency might need to be marked as [ignored] or [reviewed] if either of those scenarios are applicable.
1. If the used license should be allowable without review (if your entity has a legal team, they may want to review this assessment), ensure the license SPDX is set as [allowed] in the licensed configuration file.

[allowed]: ../configuration/allowed_licenses.md
[ignored]: ../configuration/ignoring_dependencies.md
[reviewed]: ../configuration/reviewing_dependencies.md
