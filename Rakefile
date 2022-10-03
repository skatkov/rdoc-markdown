require "bundler/gem_tasks"
require "rake/testtask"
require "standard/rake"

Rake::TestTask.new do |t|
  t.verbose = true
  t.warning = false
  t.test_files = FileList["test/test*.rb"]
end

task default: [:test, "standard:fix"]
