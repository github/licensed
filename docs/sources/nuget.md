# NuGet

The NuGet source will detect ProjectReference-style restored packages by inspecting `project.assets.json` files for dependencies. It requires that `dotnet restore` has already ran on the project, and that a `nuget.config` exists at the root.

### Search strategy
This source looks for licenses:
1. Specified by SPDX expression via `<license type="expression">` in a package's `.nuspec`
2. Specified by filepath via `<license type="file">` in a package's `.nuspec`
3. Specified by `<licenseUrl>` in a package's `.nuspec`. Depending on the URL, the license can sometimes be determined without downloading the license content.
4. In license files such as `LICENSE.txt`, even if not specified in the `.nuspec` 

### Customizing the obj root
If your project's `obj` folder isn't located within the source tree, you can change it in the licensed configuration:
```yml
nuget:
  obj_root: ../obj
```

### Excluding projects
You can exclude projects from being evaluated by using:
```yml
nuget:
  projects:
    exclude:
      - Foo.Tests
```

You can also have `licensed` emit a list of the projects that consume a dependency into the cached dependency files by using:
```yml
nuget:
  projects:
    dump: true
```
This can help you determine projects that you may wish to exclude.