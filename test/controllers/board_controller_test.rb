require "test_helper"

class BoardControllerTest < ActionDispatch::IntegrationTest
  test "create a company and move a role on the board api" do
    post api_clients_path, params: { name: "Mongoose Press", note: "Winter list" }, as: :json
    assert_response :created
    client_id = response.parsed_body.fetch("id")

    post api_commissions_path, params: {
      title: "Cover system",
      client_id: client_id,
      notes: "Six titles",
      listing: "Rails and Vue."
    }, as: :json
    assert_response :created
    job_id = response.parsed_body.fetch("id")

    post move_api_commission_path(job_id), params: { state: "interview" }, as: :json
    assert_response :success

    get api_board_path, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal "Cover system", body.fetch("columns").fetch("interview").first.fetch("title")
    assert_equal "Mongoose Press", body.fetch("clients").first.fetch("name")
    assert body.fetch("profile").key?("skills")

    get root_path
    assert_response :success
    assert_select "#folio"
  end

  test "updates a profile and returns it on the board" do
    patch api_profile_path, params: {
      name: "Antonette Caldwell",
      headline: "Rails and tokens",
      skills: [ "Rails", "Vue" ]
    }, as: :json
    assert_response :success
    assert_equal [ "Rails", "Vue" ], response.parsed_body.fetch("skills")

    get api_board_path, as: :json
    assert_equal "Rails and tokens", response.parsed_body.fetch("profile").fetch("headline")
  end
end
