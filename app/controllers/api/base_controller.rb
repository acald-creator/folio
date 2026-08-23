module Api
  class BaseController < ApplicationController
    wrap_parameters false

    rescue_from Folio::Error do |error|
      render json: { error: error.message }, status: :unprocessable_entity
    end
  end
end
