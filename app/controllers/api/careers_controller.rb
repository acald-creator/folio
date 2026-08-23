module Api
  class CareersController < BaseController
    def lookup
      render json: Folio::Careers.lookup(params[:url], skills: studio.profile[:skills])
    end

    def import
      job = studio.import_posting(
        company_name: params[:company],
        title: params[:title],
        listing: params[:listing],
        url: params[:url],
        location: params[:location]
      )
      render json: { id: job.id }, status: :created
    end
  end
end
