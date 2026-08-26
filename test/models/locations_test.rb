# frozen_string_literal: true

require "test_helper"

class FolioLocationsTest < ActiveSupport::TestCase
  test "recognizes common US location strings" do
    assert Folio::Locations.us?("San Francisco")
    assert Folio::Locations.us?("Remote, United States")
    assert Folio::Locations.us?("Remote - US")
    assert Folio::Locations.us?("New York, NY")
    assert Folio::Locations.us?("Austin, Texas")
    assert Folio::Locations.us?("Remote, Canada; Remote, United States")
    assert Folio::Locations.us?("United States of America")
  end

  test "rejects non-US locations" do
    refute Folio::Locations.us?(nil)
    refute Folio::Locations.us?("")
    refute Folio::Locations.us?("N/A")
    refute Folio::Locations.us?("Remote")
    refute Folio::Locations.us?("London, United Kingdom")
    refute Folio::Locations.us?("Bangalore")
    refute Folio::Locations.us?("Remote, Canada")
    refute Folio::Locations.us?("Berlin, Germany")
    refute Folio::Locations.us?("Remote UK")
  end
end
