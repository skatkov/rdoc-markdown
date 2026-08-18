# frozen_string_literal: true

# Selects RDoc objects that produce Markdown output.
module RDoc::Generator::Markdown::Selection
  # Returns sorted classes and modules with renderable content.
  #
  # @param store [RDoc::Store] Documentation store.
  #
  # @return [Array<RDoc::Context>] Selected classes and modules.
  def classes(store)
    store.unique_classes_and_modules.select(&:display?).select { |klass| renderable_class?(klass) }.sort
  end

  # Checks whether a class or module has content worth rendering.
  #
  # @param klass [RDoc::Context] Candidate class or module.
  #
  # @return [Boolean] Whether the object should produce a page.
  def renderable_class?(klass)
    klass.in_files.any? ||
      klass.documented? ||
      klass.includes.any? ||
      klass.method_list.any?(&:display?) ||
      klass.constants.any?(&:display?) ||
      klass.attributes.any?(&:display?) ||
      klass.sections.any? { |section| section.title.to_s.match?(/\S/) || !section.to_document.empty? }
  end

  # Returns sorted documentation pages supported by the generator.
  #
  # @param store [RDoc::Store] Documentation store.
  #
  # @return [Array<RDoc::TopLevel>] Selected pages.
  def pages(store)
    store.all_files.select(&:text?).select(&:display?)
      .select { |page| page.relative_name.match?(/\.(?:md|markdown|rdoc)\z/i) }
      .sort_by(&:base_name)
  end

  module_function :classes, :renderable_class?, :pages
end
