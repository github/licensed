# Commands

Run `licensed -h` to see help content for running licensed commands.

## `list`

Running the list command finds the dependencies for all sources in all configured applications.  No additional actions are taken on each dependency.

An optional `--sources` flag can be given to limit which dependency sources are run.  This is a filter over sources that are enabled via the licensed configuration file and cannot be used to run licensed with a disabled source.

## `cache`

The cache command finds all dependencies and ensures that each dependency has an up-to-date cached record.

An optional `--sources` flag can be given to limit which dependency sources are run.  This is a filter over sources that are enabled via the licensed configuration file and cannot be used to run licensed with a disabled source.

Dependency records will be saved if:
1. The `force` option is set
2. No cached record is found
3. The cached record's version is different than the current dependency's version
   - If the cached record's license text contents matches the current dependency's license text then the `license` metadata from the cached record is retained for the new saved record.

After the cache command is run, any cached records that don't match up to a current application dependency will be deleted.

## `status`

The status command finds all dependencies and checks whether each dependency has a valid cached record.

An optional `--sources` flag can be given to limit which dependency sources are run.  This is a filter over sources that are enabled via the licensed configuration file and cannot be used to run licensed with a disabled source.

A dependency will fail the status checks if:
1. No cached record is found
2. The cached record's version is different than the current dependency's version
3. The cached record's `licenses` data is empty
4. The cached record's `license` metadata doesn't match an `allowed` license from the dependency's application configuration.
   - If `license: other` is specified and all of the `licenses` entries match an `allowed` license a failure will not be logged
5. The cached record is flagged for re-review.
   - This occurs when the record's license text has changed since the record was reviewed.

## `notices`

Outputs license and notice text for all dependencies in each app into a `NOTICE` file in the app's `cache_path`.  If an app uses a shared cache path, the file name will contain the app name as well, e.g. `NOTICE.my_app`.

An optional `--sources` flag can be given to limit which dependency sources are run.  This is a filter over sources that are enabled via the licensed configuration file and cannot be used to run licensed with a disabled source.

The `NOTICE` file contents are retrieved from cached records, with the assumption that cached records have already been reviewed in a compliance workflow.

## `env`

Prints the runtime environment used by licensed after loading a configuration file.  By default the output is in YAML format, but can be output in JSON using the `--json` flag.

The output will not be equivalent to configuration input.  For example, all paths will be

## `version`

Displays the current licensed version.

# Adding a new command

## Implement new `Command` class

Licensed commands inherit and override the [`Licensed::Sources::Command`](../lib/licensed/commands/command.rb) class.

#### Required method overrides
1. `Licensed::Commands::Command#evaluate_dependency`
   - Runs a command execution on an application dependency.

The `evaluate_dependency` method should contain the specific command logic.  This method has access to the application configuration, dependency source enumerator and dependency currently being evaluated as well as a reporting hash to contain information about the command execution.

#### Optional method overrides

The following methods break apart the different levels of command execution.  Each method wraps lower levels of command execution in a corresponding reporter method.

1. `Licensed::Commands::Command#run`
   - Runs `run_app` for each application configuration found.  Wraps the execution of all applications in `Reporter#report_run`.
2. `Licensed::Commands::Command#run_app`
   - Runs `run_source` for each dependency source enumerator enabled for the application configuration.  Wraps the execution of all sources in `Reporter#report_app`.
3. `Licensed::Commands::Command#run_source`
   - Runs `run_dependency` for each dependency found in the source.  Wraps the execution of all dependencies in `Reporter#report_source`.
4. `Licensed::Commands::Command#run_dependency`
   - Runs `evaluate_dependency` for the dependency.  Wraps the execution of all dependencies in `Reporter#report_dependency`.

As an example, `Licensed::Commands::Command#run_app` calls `Reporter#report_app` to wrap every call to `Licensed::Commands::Command#run_source`.

##### Specifying additional report data

The `run` methods can be overridden and pass a block to `super` to provide additional reporting data or functionality.

```ruby
def run_app(app)
  super do |report|
    report["my_app_data"] = true
  end
end
```
