require "bundler/gem_tasks"
require "rake/testtask"
require "fileutils"
require "rdoc/rdoc"
require "rdoc/markdown"
require_relative "test/support/markdown_validator"

JEKYLL_SEO_TAG_NAME = "jekyll-seo-tag"
JEKYLL_SEO_TAG_REF = "v2.8.0"
JEKYLL_SEO_TAG_TITLE = "#{JEKYLL_SEO_TAG_NAME} #{JEKYLL_SEO_TAG_REF.delete_prefix("v")}"
JEKYLL_SEO_TAG_VENDOR_PATH = "vendor/#{JEKYLL_SEO_TAG_NAME}"

Rake::TestTask.new do |t|
  t.verbose = true
  t.warning = false
  t.test_files = FileList["test/test*.rb"]
end

task default: [:test]

namespace :erb do
  desc "Lint markdown ERB templates"
  task :lint do
    files = Dir["lib/templates/**/*.{md,markdown}.erb"]
    raise "No markdown ERB templates found" if files.empty?

    sh "bundle", "exec", "erb_lint", *files
  end
end

namespace :markdown do
  desc "Validate generated markdown as GitHub Flavored Markdown"
  task :validate do
    validation_root = File.expand_path("tmp/markdown-validate", __dir__)
    FileUtils.rm_rf(validation_root)
    FileUtils.mkdir_p(validation_root)

    sample_output = File.join(validation_root, "sample")
    generate_sample_docs(output: sample_output)

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
    minitest_count = MarkdownValidator.new(minitest_output).validate!
    puts "Validated #{minitest_count} markdown files in #{minitest_output}"

    Rake::Task["vendor:setup:jekyll_seo_tag"].invoke
    jekyll_seo_tag_output = File.join(validation_root, JEKYLL_SEO_TAG_NAME)
    generate_jekyll_seo_tag_docs(output: jekyll_seo_tag_output)
    jekyll_seo_tag_count = MarkdownValidator.new(jekyll_seo_tag_output).validate!
    puts "Validated #{jekyll_seo_tag_count} markdown files in #{jekyll_seo_tag_output}"

    Rake::Task["vendor:setup:rails"].invoke
    rails_root = File.expand_path("vendor/rails", __dir__)
    rails_output = File.join(validation_root, "rails")
    generate_markdown_docs(
      title: "rails validation",
      root: rails_root,
      output: rails_output,
      files: rails_validation_files(rails_root)
    )
    rails_count = MarkdownValidator.new(rails_output).validate!
    puts "Validated #{rails_count} markdown files in #{rails_output}"

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

def generate_sample_docs(output:)
  generate_markdown_docs(
    title: "sample",
    root: File.expand_path("test/data", __dir__),
    output: output,
    files: [File.expand_path("test/data/example.rb", __dir__)]
  )
end

def jekyll_seo_tag_root
  File.expand_path(JEKYLL_SEO_TAG_VENDOR_PATH, __dir__)
end

def generate_jekyll_seo_tag_docs(output:)
  root = jekyll_seo_tag_root
  unless Dir.exist?(root)
    raise "Missing #{JEKYLL_SEO_TAG_VENDOR_PATH}. Run `rake vendor:setup:jekyll_seo_tag` first."
  end

  generate_markdown_docs(
    title: JEKYLL_SEO_TAG_TITLE,
    root: root,
    output: output,
    files: Dir[File.join(root, "lib/**/*.rb")].uniq
  )
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
    generate_jekyll_seo_tag_docs(output: File.join(staged_sample_output, JEKYLL_SEO_TAG_NAME))

    FileUtils.rm_rf(sample_output)
    FileUtils.mv(staged_sample_output, sample_output)

    puts "Generated sample markdown docs in #{sample_output}"
    puts "Generated #{JEKYLL_SEO_TAG_NAME} markdown docs in #{File.join(sample_output, JEKYLL_SEO_TAG_NAME)}"
  ensure
    FileUtils.rm_rf(staging_root) if staging_root
  end
end

def minitest_docs_files(root)
  files = Dir[File.join(root, "lib/**/*.rb")]
  files.concat(Dir[File.join(root, "*.rdoc")])

  files.uniq
end

def rails_validation_files(root)
  files = Dir[File.join(root, "activesupport/lib/**/*.rb")]
  files.concat(Dir[File.join(root, "activerecord/lib/**/*.rb")])
  files.concat(Dir[File.join(root, "actionpack/lib/**/*.rb")])
  files.concat(Dir[File.join(root, "railties/lib/**/*.rb")])

  files.concat(Dir[File.join(root, "{active*,action*,railties}/README.{rdoc,md,markdown}")])

  files.uniq
end

namespace :vendor do
  namespace :setup do
    minitest_ref = "v6.0.1"
    rails_ref = ENV.fetch("RAILS_REF", "main")

    desc "Clone/update vendor/jekyll-seo-tag and checkout docs-aligned tag"
    task :jekyll_seo_tag do
      ensure_git_checkout(
        path: JEKYLL_SEO_TAG_VENDOR_PATH,
        url: "https://github.com/jekyll/jekyll-seo-tag.git",
        ref: JEKYLL_SEO_TAG_REF
      )
      Dir.chdir(JEKYLL_SEO_TAG_VENDOR_PATH) do
        sh "git fetch --tags --force"
        sh "git checkout #{JEKYLL_SEO_TAG_REF}"
      end
    end

    desc "Clone/update vendor/minitest and checkout docs-aligned tag"
    task :minitest do
      ensure_git_checkout(path: "vendor/minitest", url: "https://github.com/minitest/minitest.git", ref: minitest_ref)
      Dir.chdir("vendor/minitest") { sh "git checkout #{minitest_ref}" }
    end

    desc "Clone/update vendor/rails"
    task :rails do
      ensure_git_checkout(path: "vendor/rails", url: "https://github.com/rails/rails.git", ref: rails_ref)
    end
  end

  desc "Prepare all vendored repositories"
  task setup: ["vendor:setup:jekyll_seo_tag", "vendor:setup:minitest", "vendor:setup:rails"]

  namespace :docs do
    desc "Generate markdown docs for vendored jekyll-seo-tag"
    task :jekyll_seo_tag do
      output = File.expand_path("vendor/docs/#{JEKYLL_SEO_TAG_NAME}", __dir__)
      generate_jekyll_seo_tag_docs(output: output)
      puts "Generated #{JEKYLL_SEO_TAG_NAME} markdown docs in #{output}"
    end

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
    task all: [:jekyll_seo_tag, :minitest, :rails]
  end

  desc "Generate markdown docs for all vendored repositories"
  task docs: ["vendor:docs:all"]
end
