module Folio
  module States
    ALL = %w[inquiry booked making review done].freeze

    LABELS = {
      "inquiry" => "Inquiry",
      "booked" => "Booked",
      "making" => "Making",
      "review" => "Review",
      "done" => "Done"
    }.freeze

    def self.known?(state)
      ALL.include?(state.to_s)
    end

    def self.label(state)
      LABELS[state.to_s] || state.to_s
    end
  end
end
