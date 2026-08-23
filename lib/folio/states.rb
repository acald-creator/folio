module Folio
  module States
    ALL = %w[saved applied interview offer closed].freeze

    LABELS = {
      "saved" => "Saved",
      "applied" => "Applied",
      "interview" => "Interview",
      "offer" => "Offer",
      "closed" => "Closed"
    }.freeze

    def self.known?(state)
      ALL.include?(state.to_s)
    end

    def self.label(state)
      LABELS[state.to_s] || state.to_s
    end
  end
end
