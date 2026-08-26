require "yaml"

module Folio
  # Boards Folio scans without asking you to paste a careers URL.
  class Catalog
    Entry = Struct.new(:kind, :board, :company, :why, keyword_init: true)

    PATH = Rails.root.join("config/folio_catalog.yml")

    def self.entries
      new.entries
    end

    def self.path
      PATH
    end

    def initialize(path: PATH)
      @path = path
    end

    def entries
      rows = YAML.safe_load_file(@path, permitted_classes: [], aliases: false)
      raise Folio::Error, "Curated catalog is empty." unless rows.is_a?(Array) && rows.any?

      rows.map do |row|
        kind = row.fetch("kind").to_s
        board = row.fetch("board").to_s
        raise Folio::Error, "Catalog entry is missing a board token." if board.blank?
        raise Folio::Error, "Unknown catalog board kind: #{kind}" unless Careers::KINDS.include?(kind.to_sym)

        Entry.new(
          kind: kind.to_sym,
          board: board,
          company: row["company"].presence || board.tr("-_", " ").split.map(&:capitalize).join(" "),
          why: row["why"].to_s
        )
      end
    end
  end
end
