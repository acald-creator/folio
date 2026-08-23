repo = StudioRepo.new(Folio::Database.container)
return if repo.all_clients.any?

repo.update_profile(
  name: "Antonette Caldwell",
  headline: "Rails, tokens, and small studio tools",
  summary: "I build operator tools: a token sheet, a lockfile catalog, a webhook inbox, and this board.",
  skills: [
    "Ruby", "Rails", "ROM", "Vue", "ReScript", "TypeScript", "Go", "C#",
    "SQLite", "Design tokens"
  ]
)

press = repo.create_client(
  name: "Mongoose Press",
  note: "Literary imprint. Rails shop, small design system."
)
platform = repo.create_client(
  name: "Harbor Platform",
  note: "Platform engineering. Kubernetes first."
)
studio = repo.create_client(
  name: "North Glass",
  note: "Product studio. Tokens and a Vue board."
)
relay = repo.create_client(
  name: "Relay Labs",
  note: "Go services. Occasional Rails at the edge."
)

cover = repo.create_commission(
  title: "Staff Rails engineer",
  client_id: press.id,
  state: "saved",
  due_on: Date.today + 10,
  listing: <<~TXT,
    We need a staff Rails engineer who is happy in ROM or Active Record,
    ships Vue boards, and can keep SQLite honest on a single-operator app.
    Design tokens and a small CSS compile are a plus. No Kubernetes.
  TXT
  notes: "Strong fit. Ask whether they still use ROM in production."
)
repo.add_asset(cover.id, label: "Listing", url: "https://github.com/acald-creator/folio")

repo.create_commission(
  title: "Design systems engineer",
  client_id: studio.id,
  state: "applied",
  due_on: Date.today + 6,
  listing: <<~TXT,
    Own the token pipeline. W3C design tokens, Style Dictionary, OKLCH,
    ReScript or TypeScript in the explorer, and a Rails archive for versions.
  TXT
  notes: "This is the Swatch / Specimen line of work."
)

mark = repo.create_commission(
  title: "Go services engineer",
  client_id: relay.id,
  state: "interview",
  due_on: Date.today + 21,
  listing: <<~TXT,
    Write Go services with SQLite or Postgres. Hono or stdlib HTTP is fine.
    Rails experience is useful at the edges. GraphQL is optional.
  TXT
  notes: "Medium fit. Lumen and VeriGit cover the Go / SQLite part."
)
repo.add_asset(mark.id, label: "Lumen", url: "https://github.com/acald-creator/lumen")

repo.create_commission(
  title: "Platform engineer",
  client_id: platform.id,
  state: "closed",
  due_on: Date.today + 3,
  listing: <<~TXT,
    Kubernetes, Terraform, AWS, and Java Spring Boot. You will own the
    cluster and the deploy pipeline. Python is welcome. No design tokens.
  TXT
  notes: "Wrong stack. Keep it on the board as a miss."
)

repo.create_commission(
  title: "Frontend engineer, Vue",
  client_id: studio.id,
  state: "offer",
  due_on: Date.today + 14,
  listing: <<~TXT,
    Vue 3, TypeScript, and a design-token pipeline. Rails is the shell.
    We do not need a Java or Kubernetes background.
  TXT
  notes: "Offer to compare against the Rails seat."
)
