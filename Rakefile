require "bundler/gem_tasks"
require "rake/testtask"
require "fileutils"
require "rdoc/rdoc"
require "rdoc/markdown"
require_relative "test/support/markdown_validator"

Rake::TestTask.new do |t|
  t.verbose = true
  t.warning = false
  t.test_files = FileList["test/test*.rb"]
end

task default: [:test]

namespace :markdown do
  desc "Validate generated markdown as GitHub Flavored Markdown"
  task :validate do
    strict_vendor_links = ENV["MARKDOWN_VALIDATE_STRICT_VENDOR"] == "1"
    validation_root = File.expand_path("tmp/markdown-validate", __dir__)
    FileUtils.rm_rf(validation_root)
    FileUtils.mkdir_p(validation_root)

    sample_output = File.join(validation_root, "sample")
    generate_markdown_docs(
      title: "sample",
      root: File.expand_path("test/data", __dir__),
      output: sample_output,
      files: [File.expand_path("test/data/example.rb", __dir__)]
    )

    sample_count = MarkdownValidator.new(sample_output).validate!
    puts "Validated #{sample_count} markdown files in #{sample_output}"

    example_dir = File.expand_path("example", __dir__)
    if Dir.exist?(example_dir)
      example_count = MarkdownValidator.new(example_dir).validate!
      puts "Validated #{example_count} markdown files in #{example_dir}"
    end

    Rake::Task["vendor:setup:minitest"].invoke
    minitest_root = File.expand_path("vendor/minitest", __dir__)
    minitest_output = File.join(validation_root, "minitest")
    generate_markdown_docs(
      title: "minitest",
      root: minitest_root,
      output: minitest_output,
      files: minitest_docs_files(minitest_root)
    )
    minitest_validator = MarkdownValidator.new(minitest_output, strict_links: strict_vendor_links)
    minitest_count = minitest_validator.validate!
    puts "Validated #{minitest_count} markdown files in #{minitest_output}"
    puts "Skipped #{minitest_validator.unresolved_links} unresolved local links in vendored minitest docs"

    Rake::Task["vendor:setup:rails"].invoke
    rails_root = File.expand_path("vendor/rails", __dir__)
    rails_output = File.join(validation_root, "rails")
    generate_markdown_docs(
      title: "rails validation",
      root: rails_root,
      output: rails_output,
      files: rails_validation_files(rails_root)
    )
    rails_validator = MarkdownValidator.new(rails_output, strict_links: strict_vendor_links)
    rails_count = rails_validator.validate!
    puts "Validated #{rails_count} markdown files in #{rails_output}"
    puts "Skipped #{rails_validator.unresolved_links} unresolved local links in vendored rails docs"

    puts "Markdown validation artifacts written to #{validation_root}"
  end
end

def ensure_git_checkout(path:, url:, ref: nil)
  return if Dir.exist?(path)

  FileUtils.mkdir_p(File.dirname(path))

  clone_command = ["git", "clone", "--depth", "1"]
  clone_command += ["--branch", ref] if ref
  clone_command += [url, path]

  sh clone_command.join(" ")
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

def minitest_docs_files(root)
  files = Dir[File.join(root, "lib/**/*.rb")]
  files.concat(Dir[File.join(root, "*.rdoc")])

  manifest = File.join(root, "Manifest.txt")
  files << manifest if File.file?(manifest)

  files.uniq
end

def rails_validation_files(root)
  files = Dir[File.join(root, "activesupport/lib/**/*.rb")]
  files.concat(Dir[File.join(root, "activerecord/lib/**/*.rb")])
  files.concat(Dir[File.join(root, "actionpack/lib/**/*.rb")])
  files.concat(Dir[File.join(root, "railties/lib/**/*.rb")])

  [
    "activerecord/README.rdoc",
    "actionpack/README.rdoc",
    "railties/README.rdoc",
    "railties/RDOC_MAIN.md"
  ].each do |relative_path|
    file = File.join(root, relative_path)
    files << file if File.file?(file)
  end

  files.uniq
end

namespace :vendor do
  namespace :setup do
    MINITEST_REF = "v6.0.1"
    RAILS_REF = ENV.fetch("RAILS_REF", "main")

    desc "Clone/update vendor/minitest and checkout docs-aligned tag"
    task :minitest do
      ensure_git_checkout(path: "vendor/minitest", url: "https://github.com/minitest/minitest.git", ref: MINITEST_REF)
      Dir.chdir("vendor/minitest") { sh "git checkout #{MINITEST_REF}" }
    end

    desc "Clone/update vendor/rails"
    task :rails do
      ensure_git_checkout(path: "vendor/rails", url: "https://github.com/rails/rails.git", ref: RAILS_REF)
    end
  end

  desc "Prepare all vendored repositories"
  task setup: ["vendor:setup:minitest", "vendor:setup:rails"]

  namespace :docs do
    desc "Generate markdown docs for vendored minitest"
    task :minitest do
      root = File.expand_path("vendor/minitest", __dir__)
      raise "Missing vendor/minitest. Run `rake vendor:setup:minitest` first." unless Dir.exist?(root)

      output = File.expand_path("vendor/docs/minitest", __dir__)
      generate_markdown_docs(title: "minitest", root: root, output: output, files: minitest_docs_files(root))
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
