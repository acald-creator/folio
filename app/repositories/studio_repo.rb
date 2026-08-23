require "json"
require "rom-repository"
require "redcarpet"

class StudioRepo < ROM::Repository[:clients]
  def all_clients
    clients.order { name.asc }.to_a
  end

  def client_by_slug(slug)
    clients.by_slug(slug).one
  end

  def profile
    serialize_profile(ensure_profile)
  end

  def update_profile(attrs)
    row = ensure_profile
    skills = parse_skills(attrs.key?(:skills) ? attrs[:skills] : row.skills)
    patch = {
      updated_at: Time.now.utc,
      skills: JSON.generate(skills)
    }
    patch[:name] = attrs[:name].to_s.strip if attrs.key?(:name)
    patch[:headline] = attrs[:headline].to_s.strip if attrs.key?(:headline)
    patch[:summary] = attrs[:summary].to_s.strip if attrs.key?(:summary)
    serialize_profile(profiles.by_pk(row.id).changeset(:update, patch).commit)
  end

  def board(query: nil, client_slug: nil, due: nil, min_match: nil)
    skills = profile[:skills]
    items = commissions.combine(:client, :assets).to_a.map { |row| serialize(row, skills: skills) }

    if client_slug.present?
      items = items.select { |item| item[:client][:slug] == client_slug }
    end

    if query.present?
      needle = query.to_s.downcase
      items = items.select do |item|
        item[:title].downcase.include?(needle) ||
          item[:client][:name].downcase.include?(needle) ||
          item[:listing].downcase.include?(needle)
      end
    end

    if due.to_s == "soon"
      cutoff = Date.today + 14
      items = items.select { |item| item[:due_on] && Date.parse(item[:due_on]) <= cutoff }
    end

    floor = min_match.to_s.strip
    if floor.present?
      needed = Integer(floor)
      items = items.select { |item| item[:match][:score] && item[:match][:score] >= needed }
    end

    Folio::States::ALL.index_with do |state|
      items.select { |item| item[:state] == state }.sort_by { |item| [ -(item[:match][:score] || -1), item[:due_on] || "9999-99-99", item[:title] ] }
    end
  rescue ArgumentError
    raise Folio::Error, "Match filter is not a number."
  end

  def find_or_create_client(name:, note: nil)
    name = name.to_s.strip
    existing = all_clients.find { |client| client.name.casecmp?(name) }
    return existing if existing

    create_client(name: name, note: note)
  end

  def import_posting(company_name:, title:, listing:, url: nil, location: nil)
    client = find_or_create_client(name: company_name, note: location)
    title = title.to_s.strip
    raise Folio::Error, "Title is required." if title.blank?
    if commissions.where(client_id: client.id, title: title).one
      raise Folio::Error, "That role is already on the board."
    end

    job = create_commission(
      title: title,
      client_id: client.id,
      listing: listing.to_s,
      notes: location.to_s
    )
    add_asset(job.id, label: "Posting", url: url) if url.to_s.match?(/\Ahttps?:\/\/\S+\z/i)
    job
  end

  def create_client(name:, note: nil)
    name = name.to_s.strip
    raise Folio::Error, "Company name is required." if name.blank?

    clients.changeset(:create, {
      name: name,
      slug: unique_slug(name),
      note: note.to_s.strip.presence,
      created_at: Time.now.utc,
      updated_at: Time.now.utc
    }).commit
  end

  def create_commission(title:, client_id:, state: "saved", due_on: nil, notes: "", listing: "")
    title = title.to_s.strip
    raise Folio::Error, "Title is required." if title.blank?
    raise Folio::Error, "Unknown state." unless Folio::States.known?(state)
    raise Folio::Error, "Company is required." unless clients.by_pk(client_id).one

    commissions.changeset(:create, {
      title: title,
      client_id: client_id,
      state: state.to_s,
      due_on: parse_date(due_on),
      notes: notes.to_s,
      listing: listing.to_s,
      created_at: Time.now.utc,
      updated_at: Time.now.utc
    }).commit
  end

  def update_commission(id, attrs)
    existing = commissions.by_pk(id).one
    raise Folio::Error, "Role not found." unless existing

    patch = { updated_at: Time.now.utc }
    patch[:title] = attrs[:title].to_s.strip if attrs.key?(:title)
    raise Folio::Error, "Title is required." if patch[:title] && patch[:title].blank?

    if attrs.key?(:client_id)
      raise Folio::Error, "Company is required." unless clients.by_pk(attrs[:client_id]).one
      patch[:client_id] = attrs[:client_id]
    end

    patch[:due_on] = parse_date(attrs[:due_on]) if attrs.key?(:due_on)
    patch[:notes] = attrs[:notes].to_s if attrs.key?(:notes)
    patch[:listing] = attrs[:listing].to_s if attrs.key?(:listing)
    if attrs.key?(:state)
      raise Folio::Error, "Unknown state." unless Folio::States.known?(attrs[:state])
      patch[:state] = attrs[:state].to_s
    end

    commissions.by_pk(id).changeset(:update, patch).commit
  end

  def move_commission(id, state)
    update_commission(id, state: state)
  end

  def delete_commission(id)
    existing = commissions.by_pk(id).one
    raise Folio::Error, "Role not found." unless existing

    commissions.by_pk(id).changeset(:delete).commit
  end

  def add_asset(commission_id, label:, url:)
    raise Folio::Error, "Role not found." unless commissions.by_pk(commission_id).one

    url = url.to_s.strip
    raise Folio::Error, "Use an http or https link." unless url.match?(/\Ahttps?:\/\/\S+\z/i)

    label = label.to_s.strip
    label = url if label.blank?

    assets.changeset(:create, {
      commission_id: commission_id,
      label: label,
      url: url,
      created_at: Time.now.utc
    }).commit
  end

  def delete_asset(id)
    existing = assets.by_pk(id).one
    raise Folio::Error, "Asset not found." unless existing

    assets.by_pk(id).changeset(:delete).commit
  end

  def serialize_client(client)
    {
      id: client.id,
      name: client.name,
      slug: client.slug,
      note: client.note
    }
  end

  def serialize(row, skills: profile[:skills])
    match = Folio::Matcher.score(skills, title: row.title, listing: row.listing.to_s)
    {
      id: row.id,
      title: row.title,
      state: row.state,
      due_on: row.due_on&.to_s,
      notes: row.notes.to_s,
      notes_html: markdown(row.notes),
      listing: row.listing.to_s,
      match: {
        score: match.score,
        hits: match.hits,
        gaps: match.gaps,
        detected: match.detected
      },
      client: serialize_client(row.client),
      assets: Array(row.assets).map { |asset| { id: asset.id, label: asset.label, url: asset.url } }
    }
  end

  private

  def ensure_profile
    existing = profiles.limit(1).one
    return existing if existing

    profiles.changeset(:create, {
      name: "",
      headline: "",
      summary: "",
      skills: "[]",
      created_at: Time.now.utc,
      updated_at: Time.now.utc
    }).commit
  end

  def serialize_profile(row)
    {
      id: row.id,
      name: row.name.to_s,
      headline: row.headline.to_s,
      summary: row.summary.to_s,
      skills: parse_skills(row.skills)
    }
  end

  def parse_skills(value)
    list = value.is_a?(Array) ? value : JSON.parse(value.to_s.presence || "[]")
    list.map { |skill| skill.to_s.strip }.reject(&:blank?).uniq
  rescue JSON::ParserError
    raise Folio::Error, "Skills must be a list."
  end

  def unique_slug(name)
    base = name.to_s.parameterize
    base = "company" if base.blank?
    slug = base
    suffix = 2
    while clients.by_slug(slug).one
      slug = "#{base}-#{suffix}"
      suffix += 1
    end
    slug
  end

  def parse_date(value)
    return if value.blank?

    Date.parse(value.to_s)
  rescue Date::Error
    raise Folio::Error, "Due date is not a date."
  end

  def markdown(text)
    return "" if text.blank?

    renderer = Redcarpet::Render::HTML.new(filter_html: true, safe_links_only: true, hard_wrap: true)
    Redcarpet::Markdown.new(renderer, autolink: true, tables: true, strikethrough: true).render(text)
  end
end
