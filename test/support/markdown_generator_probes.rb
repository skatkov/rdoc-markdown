# frozen_string_literal: true

require 'pathname'
require 'rdoc/markdown'

module RDocMarkdownGeneratorProbes
  class MarkdownProbe < RDoc::Generator::Markdown
    public :markdownify
    public :describe
    public :debug
    public :method_description
    public :method_link
    public :section_description
    public :finalize_markdown
    public :normalize_internal_links
    public :resolve_output_path
    public :candidate_with_parent_reductions
    public :shift_headings
    public :section_description_html
    public :normalize_definition_list_code_blocks
    public :convert_definition_list_block
    public :definition_list_line?
    public :normalize_rdoc_pre_blocks
    public :unindent_text
  end

  class MethodDescriptionProbe < MarkdownProbe
    attr_reader :describe_calls, :method_link_calls

    def initialize(*args)
      super
      @describe_calls = []
      @method_link_calls = []
      @describe_return = ''
    end

    def describe_return=(value)
      @describe_return = value
    end

    private

    def describe(code_object, **options)
      @describe_calls << [code_object, options]
      @describe_return
    end

    def method_link(method, current_class:)
      @method_link_calls << [method, current_class]
      "##{method.name}"
    end
  end

  class MethodLinkProbe < MarkdownProbe
    def output_paths=(value)
      @output_paths = value
    end

    private

    def output_path_for(code_object)
      @output_paths.fetch(code_object)
    end
  end

  class EmitPageProbe < RDoc::Generator::Markdown
    public :emit_pagefiles
    public :setup

    attr_reader :finalize_calls, :markdown_inputs

    def initialize(*args)
      super
      @finalize_calls = []
      @markdown_inputs = []
    end

    private

    def markdownify(input)
      @markdown_inputs << input
      "markdown: #{input}"
    end

    def finalize_markdown(content, current_output_path: nil)
      @finalize_calls << [content, current_output_path]
      "final: #{current_output_path}: #{content}"
    end
  end

  class NormalizePathProbe < RDoc::Generator::Markdown
    public :normalize_input_path_for_output
  end

  class ScoreProbe < RDoc::Generator::Markdown
    public :class_content_score
    public :emit_classfiles
    public :emit_csv_index
    public :normalized_full_name
    public :setup
    public :synthetic_full_name?
  end

  class EmitClassProbe < ScoreProbe
    attr_reader :finalize_calls

    def initialize(*args)
      super
      @finalize_calls = []
    end

    private

    def finalize_markdown(content, current_output_path: nil)
      @finalize_calls << [content, current_output_path]
      "finalized #{current_output_path}"
    end
  end

  class GenerateProbe < RDoc::Generator::Markdown
    attr_reader :calls

    def initialize(*args)
      super
      @calls = []
    end

    private

    def debug(str = nil)
      @calls << [:debug, str]
    end

    def setup
      @output_dir = Pathname.new('tmp/generated-docs')
      @calls << :setup
    end

    def emit_classfiles
      @calls << :emit_classfiles
    end

    def emit_pagefiles
      @calls << :emit_pagefiles
    end

    def emit_csv_index
      @calls << :emit_csv_index
    end
  end

  class SignatureProbe < RDoc::Generator::Markdown
    public :method_signature
    public :merge_method_signature_arguments
    public :normalized_method_params
    public :split_signature_arguments_and_suffix
    public :split_signature_list
    public :extract_parameter_name
    public :signature_part_mentions_name?
  end
end
