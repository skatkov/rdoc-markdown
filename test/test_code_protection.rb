# frozen_string_literal: true

require_relative "test_helper"

require "rdoc/rdoc"
require "rdoc/markdown"

class TestCodeProtection < Minitest::Test
  cover "RDoc::Generator::Markdown::CodeProtection*"

  def rewrite(markdown)
    RDoc::Generator::Markdown::CodeProtection.rewrite(markdown) { |prose| prose.gsub("old", "new").freeze }
  end

  def test_rewrites_prose_without_mutating_input_or_requiring_mutable_output
    source = "old prose"

    assert_equal "new prose", rewrite(source)
    assert_equal "old prose", source
    assert_equal "", rewrite("")
  end

  def test_restores_distinct_code_spans_in_one_pass
    source = "old `old` old ``old ` old`` old ```old `` old``` old"

    assert_equal "new `old` new ``old ` old`` new ```old `` old``` new", rewrite(source)
  end

  def test_token_indices_cannot_match_prefixes_of_other_indices
    literals = Array.new(12) { |index| "`old #{index}`" }.join(" ")

    assert_equal "new #{literals} new", rewrite("old #{literals} old")
  end

  def test_code_spans_can_cross_lines_and_contain_backslashes
    assert_equal "new `old\nold` new", rewrite("old `old\nold` old")
    assert_equal "`old\\` new", rewrite("`old\\` old")
  end

  def test_unmatched_backtick_runs_are_prose
    ["`old", "``old`", "``old```", "`old``"].each do |source|
      assert_equal source.gsub("old", "new"), rewrite(source)
    end
  end

  def test_only_an_odd_number_of_backslashes_escapes_a_code_span_opener
    [1, 2, 3, 4].each do |count|
      prefix = "\\" * count
      expected = count.odd? ? "#{prefix}`new`" : "#{prefix}`old`"

      assert_equal expected, rewrite("#{prefix}`old`")
    end
  end

  def test_protects_backtick_and_tilde_fences_with_info_strings
    ["```", "````", "~~~", "~~~~"].each do |fence|
      literal = "#{fence}ruby\nold `old`\n\nold  \n#{fence}"

      assert_equal "new\n#{literal}\nnew", rewrite("old\n#{literal}\nold")
    end
  end

  def test_fences_allow_indentation_trailing_whitespace_and_longer_closers
    literal = "   ````ruby\nold\n```\nold\n~~~\nold\n```` not a closer\nold\n  `````\t "

    assert_equal "new\n#{literal}\nnew", rewrite("old\n#{literal}\nold")

    tilde_literal = " ~~~~ruby~\nold\n~~~\nold\n  ~~~~~\t "
    assert_equal "new\n#{tilde_literal}\nnew", rewrite("old\n#{tilde_literal}\nold")
  end

  def test_restores_multiple_code_blocks_without_rewriting_their_contents
    source = "old\n```\nold\n```\nold\n~~~\nold\n~~~\nold"

    assert_equal "new\n```\nold\n```\nnew\n~~~\nold\n~~~\nnew", rewrite(source)
  end

  def test_unclosed_fences_protect_the_rest_of_the_document
    ["```", "~~~"].each do |fence|
      assert_equal "new\n#{fence}ruby\nold\n", rewrite("old\n#{fence}ruby\nold\n")
      assert_equal "new\n#{fence}ruby", rewrite("old\n#{fence}ruby")
    end
  end

  def test_literal_token_names_cannot_collide_with_protected_code
    source = "0End _0End __0End old `old`"

    assert_equal "0End _0End __0End new `old`", rewrite(source)
  end
end
