# Reviewing dependencies

**Key**: reviewed
**Default value**: none

Sometimes your projects will use a dependency with an OSS license that you don't want to globally allow but can use with individual review.
The list of reviewed dependencies is meant to cover this scenario and will prevent the status command from raising an error for
a dependency with a license not on the allowed list.

The reviewed dependency list is organized based on the dependency source type - `bundler`, `go`, etc.  Add a dependency's metadata identifier to the appropriate source type sub-property to cause `licensed` to ignore license compliance failures.  Glob patterns can be used to identify multiple internal dependencies without having to manage a large list.

_NOTE: marking a dependency as reviewed will not prevent licensed from raising an error on missing license information._

```yml
reviewed:
  bundler:
    - gem-using-unallowed-license
```
