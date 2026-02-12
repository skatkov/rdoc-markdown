require "bundler/gem_tasks"
require "rake/testtask"
require "fileutils"
require "rdoc/rdoc"
require "rdoc/markdown"

Rake::TestTask.new do |t|
  t.verbose = true
  t.warning = false
  t.test_files = FileList["test/test*.rb"]
end

task default: [:test]

def ensure_git_checkout(path:, url:)
  return if Dir.exist?(path)

  FileUtils.mkdir_p(File.dirname(path))
  sh "git clone #{url} #{path}"
end

def generate_markdown_docs(title:, root:, output:, files:)
  raise "No input files for #{title}" if files.empty?

  FileUtils.rm_rf(output)
  FileUtils.mkdir_p(output)

  options = RDoc::Options.new
  options.setup_generator("markdown")
  options.verbosity = 0
  options.files = files
  options.op_dir = output
  options.root = root
  options.title = title
  options.force_output = true

  RDoc::RDoc.new.document(options)
end

namespace :vendor do
  namespace :setup do
    desc "Clone/update vendor/minitest and checkout docs-aligned tag"
    task :minitest do
      ensure_git_checkout(path: "vendor/minitest", url: "https://github.com/minitest/minitest.git")
      Dir.chdir("vendor/minitest") do
        sh "git fetch --tags --quiet"
        sh "git checkout v6.0.1"
      end
    end

    desc "Clone/update vendor/rails"
    task :rails do
      ensure_git_checkout(path: "vendor/rails", url: "https://github.com/rails/rails.git")
    end
  end

  desc "Prepare all vendored repositories"
  task setup: ["vendor:setup:minitest", "vendor:setup:rails"]

  namespace :docs do
    desc "Generate markdown docs for vendored minitest"
    task :minitest do
      root = File.expand_path("vendor/minitest", __dir__)
      raise "Missing vendor/minitest. Run `rake vendor:setup:minitest` first." unless Dir.exist?(root)

      files = Dir[File.join(root, "lib/**/*.rb")]
      files.concat(Dir[File.join(root, "*.rdoc")])

      manifest = File.join(root, "Manifest.txt")
      files << manifest if File.file?(manifest)

      output = File.expand_path("vendor/docs/minitest", __dir__)
      generate_markdown_docs(title: "minitest", root: root, output: output, files: files)
      puts "Generated minitest markdown docs in #{output}"
    end

    desc "Generate markdown docs for vendored rails"
    task :rails do
      root = File.expand_path("vendor/rails", __dir__)
      raise "Missing vendor/rails. Run `rake vendor:setup:rails` first." unless Dir.exist?(root)

      files = Dir[File.join(root, "*/lib/**/*.rb")]

      active_record_readme = File.join(root, "activerecord/README.rdoc")
      files << active_record_readme if File.file?(active_record_readme)

      output = File.expand_path("vendor/docs/rails", __dir__)
      generate_markdown_docs(title: "rails", root: root, output: output, files: files)
      puts "Generated rails markdown docs in #{output}"
    end

    desc "Generate markdown docs for all vendored repositories"
    task all: [:minitest, :rails]
  end

  desc "Generate markdown docs for all vendored repositories"
  task docs: ["vendor:docs:all"]
end
