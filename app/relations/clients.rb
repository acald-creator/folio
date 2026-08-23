class Clients < ROM::Relation[:sql]
  schema(:clients, infer: true) do
    associations do
      has_many :commissions
    end
  end

  def by_slug(slug)
    where(slug: slug)
  end
end
