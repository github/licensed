# npm

The npm source will detect dependencies `package.json` is found at an apps `source_path`.  It uses `npm list` to enumerate dependencies and metadata.

### Including development dependencies

By default, the npm source will exclude all non-development dependencies.  To include development or test dependencies, set `production_only: false` in the licensed configuration.

```yml
npm:
  production_only: false
```
