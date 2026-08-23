class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  helper_method :studio

  private

  def studio
    @studio ||= StudioRepo.new(Folio::Database.container)
  end
end
