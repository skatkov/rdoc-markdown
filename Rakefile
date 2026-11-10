require "bundler/gem_tasks"
require "rake/testtask"
require "fileutils"
require "rdoc/rdoc"
require "rdoc/markdown"
require_relative "test/support/markdown_validator"
require "reek/rake/task"

def minitest_docs_files(root)
  Dir[File.join(root, "lib/**/*.rb")] + Dir[File.join(root, "*.rdoc")]
end

def reverse_markdown_docs_files(root)
  Dir[File.join(root, "lib/**/*.rb")] + Dir[File.join(root, "*.md")]
end

def jekyll_seo_tag_docs_files(root)
  Dir[File.join(root, "lib/**/*.rb")]
end

def rails_docs_files(root)
  Dir[File.join(root, "*/lib/**/*.rb")] + Dir[File.join(root, "activerecord/README.rdoc")]
end

def rails_validation_files(root)
  globs = %w[
    activesupport/lib/**/*.rb
    activemodel/lib/**/*.rb
    activerecord/lib/**/*.rb
    actionpack/lib/**/*.rb
    actionview/lib/action_view/helpers/asset_tag_helper.rb
    railties/lib/**/*.rb
    {active*,action*,railties}/README.{rdoc,md,markdown}
  ]
  globs.flat_map { |glob| Dir[File.join(root, glob)] }.uniq
end

# Vendored projects used for generated docs and validation.
VENDORS = {
  jekyll_seo_tag: {
    url: "https://github.com/jekyll/jekyll-seo-tag.git",
    ref: "v2.8.0",
    path: "vendor/jekyll-seo-tag",
    files: method(:jekyll_seo_tag_docs_files)
  },
  minitest: {
    url: "https://github.com/minitest/minitest.git",
    ref: "v6.0.1",
    path: "vendor/minitest",
    files: method(:minitest_docs_files)
  },
  reverse_markdown: {
    url: "https://github.com/xijo/reverse_markdown.git",
    ref: "v3.0.2",
    path: "vendor/reverse_markdown",
    files: method(:reverse_markdown_docs_files)
  },
  rails: {
    url: "https://github.com/rails/rails.git",
    ref: ENV.fetch("RAILS_REF", "v8.1.4.1"),
    path: "vendor/rails",
    files: method(:rails_docs_files),
    validation_files: method(:rails_validation_files)
  }
}.freeze

Rake::TestTask.new do |t|
  t.verbose = true
  t.warning = false
  t.test_files = FileList["test/test*.rb"]
end

Reek::Rake::Task.new do |t|
  t.fail_on_error = true
  t.verbose = false
  t.source_files = "lib/**/*.rb"
end

task default: [:test, :reek]

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

def generate_sample_docs(output:)
  generate_markdown_docs(
    title: "sample",
    root: File.expand_path("test/data", __dir__),
    output: output,
    files: [File.expand_path("test/data/example.rb", __dir__)]
  )
end

# Generates docs for a vendored project, by default from its full file list.
def generate_vendor_docs(name, output:, files: VENDORS.fetch(name).fetch(:files))
  path = VENDORS.fetch(name).fetch(:path)
  root = File.expand_path(path, __dir__)
  raise "Missing #{path}. Run `rake vendor:setup:#{name}` first." unless Dir.exist?(root)

  generate_markdown_docs(title: name.to_s, root: root, output: output, files: files.call(root))
end

namespace :markdown do
  desc "Validate generated markdown as GitHub Flavored Markdown"
  task :validate do
    validation_root = File.expand_path("tmp/markdown-validate", __dir__)
    FileUtils.rm_rf(validation_root)
    FileUtils.mkdir_p(validation_root)

    outputs = [File.join(validation_root, "sample")]
    generate_sample_docs(output: outputs.last)
    outputs << File.expand_path("example", __dir__)

    VENDORS.each do |name, vendor|
      Rake::Task["vendor:setup:#{name}"].invoke
      outputs << File.join(validation_root, File.basename(vendor.fetch(:path)))
      generate_vendor_docs(name, output: outputs.last, files: vendor.fetch(:validation_files, vendor.fetch(:files)))
    end

    outputs.each do |output|
      puts "Validated #{MarkdownValidator.new(output).validate!} markdown files in #{output}"
    end
    puts "Markdown validation artifacts written to #{validation_root}"
  end
end

namespace :examples do
  desc "Generate checked-in example markdown docs"
  task :generate do
    Rake::Task["vendor:setup:jekyll_seo_tag"].invoke

    sample_output = File.expand_path("example", __dir__)
    staging_root = File.expand_path("tmp/examples-generate", __dir__)
    staged_sample_output = File.join(staging_root, "example")

    FileUtils.rm_rf(staging_root)
    generate_sample_docs(output: staged_sample_output)
    generate_vendor_docs(:jekyll_seo_tag, output: File.join(staged_sample_output, "jekyll-seo-tag"))

    FileUtils.rm_rf(sample_output)
    FileUtils.mv(staged_sample_output, sample_output)

    puts "Generated sample and jekyll-seo-tag markdown docs in #{sample_output}"
  ensure
    FileUtils.rm_rf(staging_root) if staging_root
  end
end

namespace :vendor do
  namespace :setup do
    VENDORS.each do |name, vendor|
      desc "Clone vendor/#{File.basename(vendor.fetch(:path))} and checkout #{vendor.fetch(:ref)}"
      task name do
        path = vendor.fetch(:path)
        ref = vendor.fetch(:ref)
        unless Dir.exist?(path)
          FileUtils.mkdir_p(File.dirname(path))
          sh "git", "clone", "--depth", "1", "--branch", ref, vendor.fetch(:url), path
        end
        # A copy without .git would make git act on this repository instead.
        Dir.chdir(path) { sh "git", "checkout", "--quiet", ref } if Dir.exist?(File.join(path, ".git"))
      end
    end
  end

  desc "Prepare all vendored repositories"
  task setup: VENDORS.keys.map { |name| "vendor:setup:#{name}" }

  namespace :docs do
    VENDORS.each do |name, vendor|
      desc "Generate markdown docs for vendored #{name}"
      task name do
        output = File.expand_path("vendor/docs/#{File.basename(vendor.fetch(:path))}", __dir__)
        generate_vendor_docs(name, output: output)
        puts "Generated #{name} markdown docs in #{output}"
      end
    end

    desc "Generate markdown docs for all vendored repositories"
    task all: VENDORS.keys
  end

  desc "Generate markdown docs for all vendored repositories"
  task docs: ["vendor:docs:all"]
end
