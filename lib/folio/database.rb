require "fileutils"
require "rom"
require "rom-sql"
require "sequel"

module Folio
  class Database
    class << self
      def url
        path = Rails.root.join("db/folio_#{Rails.env}.sqlite3")
        "sqlite://#{path}"
      end

      def connection
        @connection ||= Sequel.connect(url).tap do |db|
          db.run("PRAGMA foreign_keys = ON") if db.database_type == :sqlite
        end
      end

      def migrate!
        FileUtils.mkdir_p(Rails.root.join("db"))
        Sequel.extension :migration
        Sequel::Migrator.run(connection, Rails.root.join("db/migrate").to_s)
      end

      def container
        @container ||= begin
          migrate!
          ROM.container(:sql, connection) do |config|
            config.register_relation(Clients, Commissions, Assets)
          end
        end
      end

      def reset!
        @container = nil
        if @connection
          @connection.disconnect
          @connection = nil
        end
      end

      def wipe!
        conn = connection
        %i[assets commissions clients].each do |table|
          conn[table].delete if conn.table_exists?(table)
        end
      end
    end
  end
end
