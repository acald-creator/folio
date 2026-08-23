module Api
  class AssetsController < BaseController
    def create
      asset = studio.add_asset(params[:commission_id], label: params[:label], url: params[:url])
      render json: { id: asset.id, label: asset.label, url: asset.url }, status: :created
    end

    def destroy
      studio.delete_asset(params[:id])
      render json: { ok: true }
    end
  end
end
