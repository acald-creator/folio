class Commissions < ROM::Relation[:sql]
  schema(:commissions, infer: true) do
    associations do
      belongs_to :client
      has_many :assets
    end
  end
end
