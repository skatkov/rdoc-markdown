# frozen_string_literal: true

require "rdoc/rdoc"

module RDocTestHelpers
  def generator_options(op_dir:, root: nil)
    RDoc::Options.new.tap do |options|
      options.op_dir = op_dir
      options.root = root
    end
  end

  def rdoc_store(classes: [], pages: nil)
    RDoc::Store.new(RDoc::Options.new).tap do |store|
      classes.each do |klass|
        klass.store = store
        store.classes_hash[klass.full_name] = klass
      end

      Array(pages).each do |page|
        page.store = store
        store.files_hash[page.relative_name] = page
      end
    end
  end

  def rdoc_file(store = rdoc_store, name: "source.rb")
    store.add_file(name)
  end

  def rdoc_page(store = nil, relative_name:, comment:, parser: RDoc::Parser::Markdown, display: true)
    page = store ? store.add_file(relative_name, parser: parser) : RDoc::TopLevel.new(relative_name)
    page.parser = parser if parser && store.nil?
    page.comment = RDoc::Comment.new(comment)
    page.done_documenting = true unless display
    page
  end

  def rdoc_class(full_name, comment: nil, store: rdoc_store)
    location = rdoc_file(store)

    RDoc::NormalClass.new(full_name).tap do |klass|
      klass.full_name = full_name
      klass.store = store
      klass.add_comment(RDoc::Comment.new(comment), location) unless comment.nil?
    end
  end

  def build_rdoc_class(full_name:, description: "", methods: 0, constants: 0, attributes: 0)
    store = rdoc_store
    location = RDoc::TopLevel.new("#{full_name.tr(":", "_")}.rb")
    location.store = store

    RDoc::NormalClass.new(full_name).tap do |klass|
      klass.store = store
      klass.full_name = full_name
      klass.add_comment(RDoc::Comment.new(description), location) unless description.nil?

      Array.new(methods) { |index| klass.add_method(rdoc_method("hidden_#{index}", visible: false)) }
      Array.new(constants) { |index| klass.add_constant(rdoc_constant("CONST_#{index}", visible: false)) }
      Array.new(attributes) { |index| klass.add_attribute(rdoc_attribute("attribute_#{index}", visible: false)) }
    end
  end

  def rdoc_section(comment:, store: rdoc_store, parent: :default_parent, section_store: store)
    parent = rdoc_file(store) if parent == :default_parent
    RDoc::Context::Section.new(parent, "section", RDoc::Comment.new(comment), section_store)
  end

  def rdoc_method(name = "run", parent: nil, comment: nil, visible: true, signature: nil, params: nil)
    RDoc::AnyMethod.new("", name).tap do |method|
      method.parent = parent if parent
      method.comment = RDoc::Comment.new(comment) unless comment.nil?
      method.done_documenting = true unless visible
      method.call_seq = (signature && signature.match?(/\S/)) ? "#{name}#{signature}" : signature unless signature.nil?
      method.params = params unless params.nil?
    end
  end

  def rdoc_constant(name, visible: true)
    RDoc::Constant.new(name, "1", "").tap do |constant|
      constant.done_documenting = true unless visible
    end
  end

  def rdoc_attribute(name, visible: true)
    RDoc::Attr.new("", name, "RW", "").tap do |attribute|
      attribute.done_documenting = true unless visible
    end
  end
end
