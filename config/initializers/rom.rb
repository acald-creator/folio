Rails.application.config.to_prepare do
  Folio::Database.reset! if Rails.env.development?
end

Rails.application.config.after_initialize do
  Folio::Database.migrate!
end
