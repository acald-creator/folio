# Folio

Role board. Save a job, paste the listing, see how it matches your
skills. Drag the card as you apply.

Rails is the shell. [ROM](https://rom-rb.org) stores companies, roles,
and a profile. [Vue](https://vuejs.org) is the board. Matching is
word overlap, not a model.

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

## License

MIT
