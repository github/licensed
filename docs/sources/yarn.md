# Yarn

The yarn source will detect dependencies when `package.json` and `yarn.lock` are found at an app's `source_path`.

It uses `yarn list` to enumerate dependencies and `yarn info` to get metadata on each package.

### Including development dependencies

Yarn versions < 1.3.0 will always include non-production dependencies due to a bug in those yarn versions.

Starting with yarn version >= 1.3.0, the yarn source excludes non-production dependencies by default.  To include development and test dependencies, set `production_only: false` in `.licensed.yml`.

```yml
yarn:
  production_only: false
```
