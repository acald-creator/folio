require "test_helper"

class CareersControllerTest < ActionDispatch::IntegrationTest
  test "lookup rejects an unknown host" do
    post "/api/careers/lookup", params: { url: "https://linkedin.com/jobs/view/1" }, as: :json
    assert_response :unprocessable_entity
    assert_match(/Greenhouse/, response.parsed_body.fetch("error"))
  end

  test "matched endpoint returns the curated feed shape" do
    original = Folio::Careers.method(:matched)
    Folio::Careers.define_singleton_method(:matched) do |**|
      {
        min: 25,
        scanned: 1,
        jobs: [
          {
            title: "Staff Rails engineer",
            company: "Mongoose Press",
            location: "Remote",
            url: "https://boards.greenhouse.io/mongoose/jobs/11",
            listing: "Rails and Vue",
            source: "greenhouse",
            why: "Rails product work.",
            match: { score: 80, hits: [ "Rails" ], gaps: [], detected: [ "Rails" ] }
          }
        ],
        errors: []
      }
    end

    get "/api/careers/matched", params: { min: 25 }, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal 25, body.fetch("min")
    assert_equal "Staff Rails engineer", body.fetch("jobs").first.fetch("title")
  ensure
    Folio::Careers.define_singleton_method(:matched, original)
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
