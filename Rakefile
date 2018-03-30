# frozen_string_literal: true
require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"

desc "Run source setup scripts"
task :setup do
  Dir["script/source-setup/*"].each do |script|
    # green
    puts "\033[32mRunning #{script}.\e[0m"

    if system(script)
      # green
      puts "\033[32mCompleted #{script}.\e[0m"
    elsif $?.exitstatus == 127
      # yellow
      puts "\033[33mSkipped #{script}.\e[0m"
    else
      # red
      puts "\033[31mEncountered an error running #{script}.\e[0m"
    end

    puts
  end
end

sources_search = File.expand_path("lib/licensed/source/*.rb", __dir__)
sources = Dir[sources_search].map { |f| File.basename(f, ".*") }

namespace :test do
  sources.each do |source|
    # hidden task to set ENV and filter tests to the given source
    # see `each_source` in test/test_helper.rb
    namespace source.to_sym do
      task :env do
        ENV["SOURCE"] = source
      end
    end

    Rake::TestTask.new(source => "test:#{source}:env") do |t|
      t.description = "Run #{source} tests"
      t.libs << "test"
      t.libs << "lib"

      # use negative lookahead to exclude all source tests except
      # the tests for `source`
      t.test_files = FileList["test/**/*_test.rb"].exclude(/test\/source\/(?!#{source}).*?_test.rb/)
    end
  end
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

# add rubocop task
# -S adds styleguide urls to offense messages
RuboCop::RakeTask.new do |t|
  t.options.push "-S"
end

task default: :test
