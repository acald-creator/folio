module Api
  class ProfileController < BaseController
    def show
      render json: studio.profile
    end

    def update
      attrs = {}
      attrs[:name] = params[:name] if params.key?(:name)
      attrs[:headline] = params[:headline] if params.key?(:headline)
      attrs[:summary] = params[:summary] if params.key?(:summary)
      attrs[:skills] = params[:skills] if params.key?(:skills)
      render json: studio.update_profile(attrs)
    end
  end
end
