require "test_helper"

class StudioRepoTest < ActiveSupport::TestCase
  test "board groups roles and explains a due job" do
    press = studio.create_client(name: "Mongoose Press", note: "Winter list")
    glass = studio.create_client(name: "North Glass")
    studio.create_commission(
      title: "Cover system",
      client_id: press.id,
      state: "saved",
      due_on: Date.today + 5,
      notes: "Six titles.\n\n- Shared spine",
      listing: "Rails and Vue. SQLite is fine."
    )
    studio.create_commission(
      title: "Shop mark",
      client_id: glass.id,
      state: "interview",
      due_on: Date.today + 40
    )

    columns = studio.board
    assert_equal [ "Cover system" ], columns["saved"].map { |item| item[:title] }
    assert_equal [ "Shop mark" ], columns["interview"].map { |item| item[:title] }
    assert_match(/<li>/, columns["saved"].first[:notes_html])
    assert_equal "mongoose-press", columns["saved"].first[:client][:slug]
    assert_equal "Rails and Vue. SQLite is fine.", columns["saved"].first[:listing]

    soon = studio.board(due: "soon")
    assert_equal [ "Cover system" ], soon["saved"].map { |item| item[:title] }
    assert_empty soon["interview"]

    named = studio.board(query: "shop")
    assert_equal [ "Shop mark" ], named.values.flatten.map { |item| item[:title] }
  end

  test "moves a role and stores a link" do
    client = studio.create_client(name: "Abbey Ceramics")
    job = studio.create_commission(title: "Colophon", client_id: client.id)
    studio.move_commission(job.id, "offer")
    asset = studio.add_asset(job.id, label: "Specimen", url: "https://github.com/acald-creator/specimen")

    columns = studio.board
    card = columns["offer"].first
    assert_equal "Colophon", card[:title]
    assert_equal "Specimen", card[:assets].first[:label]
    assert_equal asset.id, card[:assets].first[:id]

    error = assert_raises(Folio::Error) { studio.move_commission(job.id, "shipped") }
    assert_match(/Unknown state/, error.message)

    bad_link = assert_raises(Folio::Error) { studio.add_asset(job.id, label: "notes", url: "javascript:alert(1)") }
    assert_match(/http/, bad_link.message)
  end

  test "rejects a blank role" do
    client = studio.create_client(name: "North Glass")
    error = assert_raises(Folio::Error) { studio.create_commission(title: " ", client_id: client.id) }
    assert_match(/Title/, error.message)
  end

  test "filters the board by match score" do
    studio.update_profile(skills: [ "Rails", "Vue" ])
    press = studio.create_client(name: "Mongoose Press")
    studio.create_commission(
      title: "Rails seat",
      client_id: press.id,
      listing: "Rails and Vue every day."
    )
    studio.create_commission(
      title: "Java seat",
      client_id: press.id,
      listing: "Java Spring Boot and Kubernetes."
    )

    high = studio.board(min_match: 40).values.flatten.map { |item| item[:title] }
    assert_includes high, "Rails seat"
    assert_equal [ "Rails seat" ], high
  end
end
