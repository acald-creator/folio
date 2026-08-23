repo = StudioRepo.new(Folio::Database.container)
return if repo.all_clients.any?

press = repo.create_client(
  name: "Mongoose Press",
  note: "Literary imprint. The winter list is the live job."
)
glass = repo.create_client(
  name: "North Glass",
  note: "Architectural glass. Wayfinding first, then the shop mark."
)
abbey = repo.create_client(
  name: "Abbey Ceramics",
  note: "Small kiln. Cards and a colophon. Nothing larger this season."
)

cover = repo.create_commission(
  title: "Cover system for the winter list",
  client_id: press.id,
  state: "inquiry",
  due_on: Date.today + 10,
  notes: <<~MD
    Six titles, one spine language.

    - Shared type page
    - Cloth and ochre, not a new palette
    - Ask whether Specimen already has the tokens
  MD
)
repo.add_asset(cover.id, label: "Specimen archive", url: "https://github.com/acald-creator/specimen")

repo.create_commission(
  title: "Shop wayfinding",
  client_id: glass.id,
  state: "booked",
  due_on: Date.today + 21,
  notes: "Floor plan is late. Hold type until the glass samples land."
)

mark = repo.create_commission(
  title: "Shop mark",
  client_id: glass.id,
  state: "making",
  due_on: Date.today + 6,
  notes: "One mark, two weights. Do not draw a new color story."
)
repo.add_asset(mark.id, label: "Swatch mixer", url: "https://github.com/acald-creator/swatch")

repo.create_commission(
  title: "Edition colophon",
  client_id: abbey.id,
  state: "review",
  due_on: Date.today + 3,
  notes: "Press wants the kiln mark smaller. Second proof tomorrow."
)

repo.create_commission(
  title: "Letterpress card",
  client_id: abbey.id,
  state: "done",
  due_on: Date.today - 12,
  notes: "Printed. Box is on the shelf."
)
