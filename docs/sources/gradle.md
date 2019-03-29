# Gradle

The gradle source will detect dependencies when a `build.gradle` file is found along with either `gradle` or `gradlew` executables being available. The source uses the [Gradle-License-Report](https://github.com/jk1/Gradle-License-Report) plugin to enumerate dependencies and locate their licensing information.

An active network connection is required when running the `licensed cache` command with the gradle source.  Gradle packages generally do not include license text or other legal notices, and additional network requests are needed to find and pull the necessary license content.

### Setting dependency configurations to load

The `gradle.configurations` property is used to determine which dependencies are fetched to load license information.  The default configurations are `"runtime"` and `"runtimeClassPath"`.

```yml
gradle:
  configurations:
    - runtime
    - runtimeClassPath
```
