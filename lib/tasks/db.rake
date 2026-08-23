namespace :db do
  desc "Run Sequel / ROM migrations"
  task migrate: :environment do
    Folio::Database.migrate!
    puts "Migrated #{Folio::Database.url}"
  end

  desc "Load db/seeds.rb"
  task seed: :environment do
    load Rails.root.join("db/seeds.rb")
  end
end
