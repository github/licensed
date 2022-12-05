# CocoaPods

The cocoapods source will detect dependencies when `Podfile` and `Podfile.lock` are found at an app's `source_path`.

It uses the `pod` CLI commands to enumerate dependencies and gather metadata on each package.

### Evaluating dependencies from a specific target

The `cocoapods.targets` property is used to specify which targets to analyze dependencies from. By default, dependencies from all targets will be analyzed.

```yml
cocoapods:
  targets:
    - ios
```
