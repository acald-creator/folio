require "test_helper"

class MatcherTest < ActiveSupport::TestCase
  test "scores a rails listing against a rails profile" do
    result = Folio::Matcher.score(
      [ "Ruby", "Rails", "Vue", "SQLite" ],
      title: "Staff Rails engineer",
      listing: "Rails, Vue, and SQLite. No Kubernetes."
    )

    assert_includes result.hits, "Rails"
    assert_includes result.hits, "Vue"
    assert_includes result.hits, "SQLite"
    assert_includes result.gaps, "Kubernetes"
    assert result.score >= 50
  end

  test "returns no score when the listing is empty" do
    result = Folio::Matcher.score([ "Rails" ], title: "Mystery", listing: "")
    assert_nil result.score
    assert_empty result.hits
  end

  test "does not treat go as a substring of ongoing" do
    result = Folio::Matcher.score(
      [ "Go" ],
      title: "Program manager",
      listing: "Keep the work ongoing. No cluster work."
    )
    assert_empty result.hits
  end
end
