require "rom-repository"
require "redcarpet"

class StudioRepo < ROM::Repository[:clients]
  def all_clients
    clients.order { name.asc }.to_a
  end

  def client_by_slug(slug)
    clients.by_slug(slug).one
  end

  def board(query: nil, client_slug: nil, due: nil)
    items = commissions.combine(:client, :assets).to_a.map { |row| serialize(row) }

    if client_slug.present?
      items = items.select { |item| item[:client][:slug] == client_slug }
    end

    if query.present?
      needle = query.to_s.downcase
      items = items.select do |item|
        item[:title].downcase.include?(needle) || item[:client][:name].downcase.include?(needle)
      end
    end

    if due.to_s == "soon"
      cutoff = Date.today + 14
      items = items.select { |item| item[:due_on] && Date.parse(item[:due_on]) <= cutoff }
    end

    Folio::States::ALL.index_with do |state|
      items.select { |item| item[:state] == state }.sort_by { |item| [ item[:due_on] || "9999-99-99", item[:title] ] }
    end
  end

  def create_client(name:, note: nil)
    name = name.to_s.strip
    raise Folio::Error, "Client name is required." if name.blank?

    clients.changeset(:create, {
      name: name,
      slug: unique_slug(name),
      note: note.to_s.strip.presence,
      created_at: Time.now.utc,
      updated_at: Time.now.utc
    }).commit
  end

  def create_commission(title:, client_id:, state: "inquiry", due_on: nil, notes: "")
    title = title.to_s.strip
    raise Folio::Error, "Title is required." if title.blank?
    raise Folio::Error, "Unknown state." unless Folio::States.known?(state)
    raise Folio::Error, "Client is required." unless clients.by_pk(client_id).one

    commissions.changeset(:create, {
      title: title,
      client_id: client_id,
      state: state.to_s,
      due_on: parse_date(due_on),
      notes: notes.to_s,
      created_at: Time.now.utc,
      updated_at: Time.now.utc
    }).commit
  end

  def update_commission(id, attrs)
    existing = commissions.by_pk(id).one
    raise Folio::Error, "Commission not found." unless existing

    patch = { updated_at: Time.now.utc }
    patch[:title] = attrs[:title].to_s.strip if attrs.key?(:title)
    raise Folio::Error, "Title is required." if patch[:title] && patch[:title].blank?

    if attrs.key?(:client_id)
      raise Folio::Error, "Client is required." unless clients.by_pk(attrs[:client_id]).one
      patch[:client_id] = attrs[:client_id]
    end

    patch[:due_on] = parse_date(attrs[:due_on]) if attrs.key?(:due_on)
    patch[:notes] = attrs[:notes].to_s if attrs.key?(:notes)
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
    raise Folio::Error, "Commission not found." unless existing

    commissions.by_pk(id).changeset(:delete).commit
  end

  def add_asset(commission_id, label:, url:)
    raise Folio::Error, "Commission not found." unless commissions.by_pk(commission_id).one

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

  def serialize(row)
    {
      id: row.id,
      title: row.title,
      state: row.state,
      due_on: row.due_on&.to_s,
      notes: row.notes.to_s,
      notes_html: markdown(row.notes),
      client: serialize_client(row.client),
      assets: Array(row.assets).map { |asset| { id: asset.id, label: asset.label, url: asset.url } }
    }
  end

  private

  def unique_slug(name)
    base = name.to_s.parameterize
    base = "client" if base.blank?
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
