# frozen_string_literal: true
require "bundler/gem_tasks"
require "rake/testtask"

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

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test
