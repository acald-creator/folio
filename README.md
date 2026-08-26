# Folio

Role board. Folio scans a curated list of public Greenhouse and Ashby
career boards, scores open roles against your skills, and lets you save
a card. You can still paste one careers URL or a listing by hand.

Matching is word overlap, not a model. Drag the card as you apply.

Saved → applied → interview → offer → closed.

## Run

Needs Ruby 3.2+ and Node 22.

```bash
bundle install
npm install
npm run build
bin/rails db:migrate
bin/rails db:seed
bin/rails server -p 4020
```

Seed loads a profile and five roles so the match column is not empty.
Edit `config/folio_catalog.yml` to change which companies Folio scans.

## License

MIT
