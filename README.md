# Folio

Studio queue. Rails is the web shell. [ROM](https://rom-rb.org) stores
clients, commissions, and asset links. [Vue](https://vuejs.org) is the
board.

Inquiry → booked → making → review → done. Open a card for markdown
notes and links. Drag it to move.

This is a new product, not a revival of `simple-rails-vue-app-rom`.

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

Seed loads a small press / glass / ceramics board.

## Why ROM and Vue

A commission is relations: a client, a state, a due date, a pile of
links. Repositories write those. Vue is the board and the filters, not
the source of truth.

Single-operator MVP: no accounts, no billing.

## Layout

```
app/relations       ROM relations
app/repositories    StudioRepo
app/controllers/api JSON for the board
frontend            Vue 3 board (Vite → app/assets/builds/folio.js)
db/migrate          Sequel migrations
```

## License

MIT
