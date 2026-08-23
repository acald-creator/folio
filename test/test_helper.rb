ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: 1)

    setup do
      Folio::Database.migrate!
      Folio::Database.wipe!
    end

    def studio
      StudioRepo.new(Folio::Database.container)
    end
  end
end
