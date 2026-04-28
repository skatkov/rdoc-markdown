# frozen_string_literal: true

require_relative "test_helper"

class TestMinitestStrictIntegration < Minitest::Test
  def test_strict_assertions_are_loaded
    assert_respond_to self, :assert_true
    assert_true true
    assert_raises(Minitest::Assertion) { assert_predicate 1, :nonzero? }
  end
end
