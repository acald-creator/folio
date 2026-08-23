class Assets < ROM::Relation[:sql]
  schema(:assets, infer: true) do
    associations do
      belongs_to :commission
    end
  end
end
