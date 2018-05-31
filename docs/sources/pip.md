# Pip

The pip source uses `pip` CLI commands to enumerate dependencies and properties. It is expected that `pip` is available in the PATH before running `licensed`

#### virtual_env_dir
A `virtualenv` is assumed to be setup before running `licensed`. The `pip` command will be sourced from this directory.
An example usage of this might look like:
```yaml
python:
    virtual_env_dir:"venv"
```
