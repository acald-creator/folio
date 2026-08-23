require "test_helper"

class StudioRepoTest < ActiveSupport::TestCase
  test "board groups commissions and explains a due job" do
    press = studio.create_client(name: "Mongoose Press", note: "Winter list")
    glass = studio.create_client(name: "North Glass")
    studio.create_commission(
      title: "Cover system",
      client_id: press.id,
      state: "inquiry",
      due_on: Date.today + 5,
      notes: "Six titles.\n\n- Shared spine"
    )
    studio.create_commission(
      title: "Shop mark",
      client_id: glass.id,
      state: "making",
      due_on: Date.today + 40
    )

    columns = studio.board
    assert_equal [ "Cover system" ], columns["inquiry"].map { |item| item[:title] }
    assert_equal [ "Shop mark" ], columns["making"].map { |item| item[:title] }
    assert_match(/<li>/, columns["inquiry"].first[:notes_html])
    assert_equal "mongoose-press", columns["inquiry"].first[:client][:slug]

    soon = studio.board(due: "soon")
    assert_equal [ "Cover system" ], soon["inquiry"].map { |item| item[:title] }
    assert_empty soon["making"]

    named = studio.board(query: "shop")
    assert_equal [ "Shop mark" ], named.values.flatten.map { |item| item[:title] }
  end

  test "moves a commission and stores an asset link" do
    client = studio.create_client(name: "Abbey Ceramics")
    job = studio.create_commission(title: "Colophon", client_id: client.id)
    studio.move_commission(job.id, "review")
    asset = studio.add_asset(job.id, label: "Specimen", url: "https://github.com/acald-creator/specimen")

    columns = studio.board
    card = columns["review"].first
    assert_equal "Colophon", card[:title]
    assert_equal "Specimen", card[:assets].first[:label]
    assert_equal asset.id, card[:assets].first[:id]

    error = assert_raises(Folio::Error) { studio.move_commission(job.id, "shipped") }
    assert_match(/Unknown state/, error.message)

    bad_link = assert_raises(Folio::Error) { studio.add_asset(job.id, label: "notes", url: "javascript:alert(1)") }
    assert_match(/http/, bad_link.message)
  end

  test "rejects a blank commission" do
    client = studio.create_client(name: "North Glass")
    error = assert_raises(Folio::Error) { studio.create_commission(title: " ", client_id: client.id) }
    assert_match(/Title/, error.message)
  end
end
