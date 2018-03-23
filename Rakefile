# frozen_string_literal: true
require "bundler/gem_tasks"
require "rake/testtask"

desc "Run source setup scripts"
task :setup do
  Dir["script/setup/*"].each { |script| system(script) }
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test
