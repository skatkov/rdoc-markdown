# frozen_string_literal: true

require_relative "test_helper"

require "rdoc/generator/markdown"

class TestCodeBlockConversion < Minitest::Test
  cover "RDoc::Generator::Markdown::Conversion*"

  def test_highlighted_code_keeps_language_and_word_boundaries
    html = '<pre class="ruby"><span class="ruby-keyword">return</span> ' \
      '<span class="ruby-identifier">value</span></pre>'

    assert_equal "```ruby\nreturn value\n```",
      RDoc::Generator::Markdown::Conversion.markdownify(html)
  end

  def test_highlighted_code_links_are_not_rewritten_as_indexing_expressions
    html = '<pre class="ruby"><span class="ruby-keyword">return</span> ' \
      '<a href=":csv"><span class="ruby-constant">Mime</span></a></pre>'

    assert_equal "```ruby\nreturn Mime\n```",
      RDoc::Generator::Markdown::Conversion.markdownify(html)
  end

  def test_highlighted_code_does_not_gain_documentation_anchors
    html = '<pre class="ruby"><span class="legacy-anchor" id="label-Example">return</span> value</pre>'

    assert_equal "```ruby\nreturn value\n```",
      RDoc::Generator::Markdown::Conversion.markdownify(html)
  end
end
