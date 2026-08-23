module Api
  class CommissionsController < BaseController
    def create
      commission = studio.create_commission(
        title: params[:title],
        client_id: params[:client_id].to_i,
        state: params[:state].presence || "inquiry",
        due_on: params[:due_on],
        notes: params[:notes]
      )
      render json: { id: commission.id }, status: :created
    end

    def update
      attrs = {}
      attrs[:title] = params[:title] if params.key?(:title)
      attrs[:client_id] = params[:client_id].to_i if params.key?(:client_id)
      attrs[:state] = params[:state] if params.key?(:state)
      attrs[:due_on] = params[:due_on] if params.key?(:due_on)
      attrs[:notes] = params[:notes] if params.key?(:notes)
      studio.update_commission(params[:id], attrs)
      render json: { ok: true }
    end

    def move
      studio.move_commission(params[:id], params[:state])
      render json: { ok: true }
    end

    def destroy
      studio.delete_commission(params[:id])
      render json: { ok: true }
    end
  end
end
