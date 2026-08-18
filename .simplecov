SimpleCov.cover "lib/**/*.rb"
SimpleCov.skip "lib/rdoc/markdown/version.rb"
SimpleCov.ignore_branches :implicit_else, :eval_generated

SimpleCov.coverage :line, minimum: 100, minimum_per_file: 100
SimpleCov.coverage :branch, minimum: 100, minimum_per_file: 100
