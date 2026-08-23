require "test_helper"

class BoardControllerTest < ActionDispatch::IntegrationTest
  test "create a client and move a commission on the board api" do
    post api_clients_path, params: { name: "Mongoose Press", note: "Winter list" }, as: :json
    assert_response :created
    client_id = response.parsed_body.fetch("id")

    post api_commissions_path, params: {
      title: "Cover system",
      client_id: client_id,
      notes: "Six titles"
    }, as: :json
    assert_response :created
    job_id = response.parsed_body.fetch("id")

    post move_api_commission_path(job_id), params: { state: "making" }, as: :json
    assert_response :success

    get api_board_path, as: :json
    assert_response :success
    body = response.parsed_body
    assert_equal "Cover system", body.fetch("columns").fetch("making").first.fetch("title")
    assert_equal "Mongoose Press", body.fetch("clients").first.fetch("name")

    get root_path
    assert_response :success
    assert_select "#folio"
  end
end
