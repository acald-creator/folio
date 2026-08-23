module Api
  class BoardController < BaseController
    def show
      render json: {
        columns: studio.board(
          query: params[:q],
          client_slug: params[:client],
          due: params[:due],
          min_match: params[:min]
        ),
        clients: studio.all_clients.map { |client| studio.serialize_client(client) },
        states: Folio::States::LABELS,
        profile: studio.profile
      }
    end
  end
end
