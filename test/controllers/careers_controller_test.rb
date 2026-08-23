require "test_helper"

class CareersControllerTest < ActionDispatch::IntegrationTest
  test "lookup rejects an unknown host" do
    post "/api/careers/lookup", params: { url: "https://linkedin.com/jobs/view/1" }, as: :json
    assert_response :unprocessable_entity
    assert_match(/Greenhouse/, response.parsed_body.fetch("error"))
  end

  test "import lands a posting on the board" do
    post "/api/careers/import", params: {
      company: "Mongoose Press",
      title: "Staff Rails engineer",
      listing: "Rails and Vue.",
      url: "https://boards.greenhouse.io/mongoose/jobs/11",
      location: "Remote"
    }, as: :json
    assert_response :created

    get api_board_path, as: :json
    card = response.parsed_body.fetch("columns").fetch("saved").first
    assert_equal "Staff Rails engineer", card.fetch("title")
    assert_equal "Mongoose Press", card.fetch("client").fetch("name")
  end
end
