module Api
  class ClientsController < BaseController
    def create
      client = studio.create_client(name: params[:name], note: params[:note])
      render json: studio.serialize_client(client), status: :created
    end
  end
end
