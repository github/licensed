# `licensed env`

Prints the runtime environment used by licensed after loading a configuration file.  This can be different from the configuration file inputs, for example all paths will be given as absolute file paths and glob paths may be expanded.

## Options

- `--config`/`-c`: the path to the licensed configuration file
   - required: true
   - default value: `./.licensed.yml`
- `--format`/`-f`: the output format
   - required: false
   - default value: `yaml`
