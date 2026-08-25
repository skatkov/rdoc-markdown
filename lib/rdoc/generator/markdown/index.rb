# frozen_string_literal: true

# Writes the generated documentation search index.
module RDoc::Generator::Markdown::Index
  private

  # Writes a CSV search index for generated documentation.
  #
  # @return [void]
  def emit_csv_index
    CSV.open("#{output_dir}/index.csv", "wb") { |csv| write_index(csv) }
  end

  # Writes all search-index rows.
  #
  # @param csv [CSV] Open CSV writer.
  #
  # @return [void]
  def write_index(csv)
    csv << %w[name type path]
    classes.each { |klass| write_class_rows(csv, klass, output_path_for(klass)) }
    pages.each { |page| csv << [File.basename(normalize_input_path_for_output(page.relative_name)), "File", page_output_path(page)] }
  end

  # Writes one class and its visible member rows.
  #
  # @param csv [CSV] Open CSV writer.
  # @param klass [RDoc::Context] Class or module to index.
  # @param output_path [String] Generated Markdown path.
  #
  # @return [void]
  def write_class_rows(csv, klass, output_path)
    class_name = klass.full_name
    csv << [class_name, klass.type.capitalize, output_path]

    klass.method_list.select(&:display?).each do |method|
      csv << ["#{class_name}.#{method.name}", "Method", "#{output_path}##{method.aref}"]
    end
    klass.constants.select(&:display?).sort.each do |const|
      name = const.name
      csv << ["#{class_name}.#{name}", "Constant", "#{output_path}##{name}"]
    end
    klass.attributes.select(&:display?).sort.each do |attr|
      csv << ["#{class_name}.#{attr.name}", "Attribute", "#{output_path}##{attr.aref}"]
    end
  end
end
