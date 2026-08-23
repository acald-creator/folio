<script setup>
import { computed, onMounted, reactive, ref } from "vue"
import * as api from "./api.js"

const columns = ref({})
const clients = ref([])
const states = ref({})
const error = ref("")
const selectedId = ref(null)
const showClient = ref(false)
const showCommission = ref(false)
const overState = ref("")

const filters = reactive({ query: "", client: "", dueSoon: false })
const clientForm = reactive({ name: "", note: "" })
const jobForm = reactive({ title: "", client_id: "", state: "inquiry", due_on: "", notes: "" })
const edit = reactive({ title: "", client_id: "", due_on: "", notes: "", state: "" })
const assetForm = reactive({ label: "", url: "" })

const selected = computed(() => {
  for (const list of Object.values(columns.value)) {
    const found = list.find((item) => item.id === selectedId.value)
    if (found) return found
  }
  return null
})

const dueSoon = (due) => {
  if (!due) return false
  const stamp = new Date(`${due}T00:00:00`)
  const cutoff = new Date()
  cutoff.setDate(cutoff.getDate() + 14)
  return stamp <= cutoff
}

async function refresh() {
  const data = await api.loadBoard(filters)
  columns.value = data.columns
  clients.value = data.clients
  states.value = data.states
}

async function run(work) {
  error.value = ""
  try {
    await work()
    await refresh()
  } catch (err) {
    error.value = err.message
  }
}

onMounted(() => run(refresh))

function applyFilters() {
  return run(refresh)
}

function open(item) {
  selectedId.value = item.id
  edit.title = item.title
  edit.client_id = String(item.client.id)
  edit.due_on = item.due_on || ""
  edit.notes = item.notes
  edit.state = item.state
  assetForm.label = ""
  assetForm.url = ""
}

function close() {
  selectedId.value = null
}

async function saveClient() {
  await run(async () => {
    await api.createClient({ name: clientForm.name, note: clientForm.note })
    clientForm.name = ""
    clientForm.note = ""
    showClient.value = false
  })
}

async function saveCommission() {
  await run(async () => {
    await api.createCommission({
      title: jobForm.title,
      client_id: Number(jobForm.client_id),
      state: jobForm.state,
      due_on: jobForm.due_on,
      notes: jobForm.notes
    })
    jobForm.title = ""
    jobForm.due_on = ""
    jobForm.notes = ""
    jobForm.state = "inquiry"
    showCommission.value = false
  })
}

async function saveEdit() {
  if (!selected.value) return
  await run(() =>
    api.updateCommission(selected.value.id, {
      title: edit.title,
      client_id: Number(edit.client_id),
      due_on: edit.due_on,
      notes: edit.notes,
      state: edit.state
    })
  )
}

async function moveTo(id, state) {
  await run(() => api.moveCommission(id, state))
}

async function removeJob() {
  if (!selected.value) return
  await run(async () => {
    await api.deleteCommission(selected.value.id)
    close()
  })
}

async function saveAsset() {
  if (!selected.value) return
  await run(async () => {
    await api.addAsset(selected.value.id, { label: assetForm.label, url: assetForm.url })
    assetForm.label = ""
    assetForm.url = ""
  })
}

async function removeAsset(id) {
  await run(() => api.deleteAsset(id))
}

function onDragStart(event, item) {
  event.dataTransfer.setData("text/plain", String(item.id))
  event.dataTransfer.effectAllowed = "move"
}

function onDrop(event, state) {
  event.preventDefault()
  overState.value = ""
  const id = Number(event.dataTransfer.getData("text/plain"))
  if (id) moveTo(id, state)
}
</script>

<template>
  <div>
    <p v-if="error" class="flash bad" role="alert">{{ error }}</p>

    <div class="toolbar">
      <form class="toolbar" @submit.prevent="applyFilters">
        <label>
          Filter
          <input v-model="filters.query" type="text" autocomplete="off" placeholder="Title or client">
        </label>
        <label>
          Client
          <select v-model="filters.client">
            <option value="">All clients</option>
            <option v-for="client in clients" :key="client.id" :value="client.slug">{{ client.name }}</option>
          </select>
        </label>
        <label class="check">
          <input v-model="filters.dueSoon" type="checkbox">
          Due in 14 days
        </label>
        <button class="primary" type="submit">Filter</button>
      </form>
      <div class="actions">
        <button type="button" @click="showClient = true">New client</button>
        <button class="primary" type="button" @click="showCommission = true">New commission</button>
      </div>
    </div>

    <section class="board" aria-label="Studio board">
      <article
        v-for="(label, state) in states"
        :key="state"
        class="column"
        :class="{ over: overState === state }"
        @dragover.prevent="overState = state"
        @dragleave="overState = ''"
        @drop="onDrop($event, state)"
      >
        <h2>{{ label }} <span>{{ (columns[state] || []).length }}</span></h2>
        <button
          v-for="item in columns[state] || []"
          :key="item.id"
          class="card"
          draggable="true"
          @dragstart="onDragStart($event, item)"
          @click="open(item)"
        >
          <strong>{{ item.title }}</strong>
          <span class="muted">{{ item.client.name }}</span>
          <span v-if="item.due_on" class="muted due" :class="{ soon: dueSoon(item.due_on) }">Due {{ item.due_on }}</span>
        </button>
      </article>
    </section>

    <div v-if="selected" class="drawer-back" @click="close"></div>
    <aside v-if="selected" class="drawer" role="dialog" aria-labelledby="job-title">
      <p class="eyebrow">{{ states[selected.state] }}</p>
      <h2 id="job-title">{{ selected.title }}</h2>
      <p class="muted">{{ selected.client.name }}</p>

      <label>
        Title
        <input v-model="edit.title" type="text">
      </label>
      <label>
        Client
        <select v-model="edit.client_id">
          <option v-for="client in clients" :key="client.id" :value="String(client.id)">{{ client.name }}</option>
        </select>
      </label>
      <label>
        State
        <select v-model="edit.state">
          <option v-for="(label, state) in states" :key="state" :value="state">{{ label }}</option>
        </select>
      </label>
      <label>
        Due
        <input v-model="edit.due_on" type="date">
      </label>
      <label>
        Notes
        <textarea v-model="edit.notes" placeholder="Markdown is fine."></textarea>
      </label>
      <div class="actions">
        <button class="primary" type="button" @click="saveEdit">Save</button>
        <button class="danger" type="button" @click="removeJob">Delete</button>
        <button type="button" @click="close">Close</button>
      </div>

      <h3 class="eyebrow" style="margin-top: 1.4rem">Note</h3>
      <div class="notes" v-html="selected.notes_html || '<p class=&quot;muted&quot;>No note yet.</p>'"></div>

      <h3 class="eyebrow">Assets</h3>
      <ul class="assets">
        <li v-for="asset in selected.assets" :key="asset.id">
          <a :href="asset.url" target="_blank" rel="noreferrer">{{ asset.label }}</a>
          <button type="button" class="danger" @click="removeAsset(asset.id)">Remove</button>
        </li>
      </ul>
      <label>
        Label
        <input v-model="assetForm.label" type="text" placeholder="Press sheet">
      </label>
      <label>
        URL
        <input v-model="assetForm.url" type="url" placeholder="https://">
      </label>
      <button type="button" @click="saveAsset">Add link</button>
    </aside>

    <div v-if="showClient" class="modal" @click.self="showClient = false">
      <form class="panel" @submit.prevent="saveClient">
        <h2>New client</h2>
        <label>
          Name
          <input v-model="clientForm.name" type="text" required autocomplete="off">
        </label>
        <label>
          Note
          <textarea v-model="clientForm.note" placeholder="Who they are, what they usually ask for."></textarea>
        </label>
        <div class="actions">
          <button class="primary" type="submit">Create client</button>
          <button type="button" @click="showClient = false">Cancel</button>
        </div>
      </form>
    </div>

    <div v-if="showCommission" class="modal" @click.self="showCommission = false">
      <form class="panel" @submit.prevent="saveCommission">
        <h2>New commission</h2>
        <label>
          Title
          <input v-model="jobForm.title" type="text" required autocomplete="off">
        </label>
        <label>
          Client
          <select v-model="jobForm.client_id" required>
            <option disabled value="">Choose a client</option>
            <option v-for="client in clients" :key="client.id" :value="String(client.id)">{{ client.name }}</option>
          </select>
        </label>
        <label>
          State
          <select v-model="jobForm.state">
            <option v-for="(label, state) in states" :key="state" :value="state">{{ label }}</option>
          </select>
        </label>
        <label>
          Due
          <input v-model="jobForm.due_on" type="date">
        </label>
        <label>
          Notes
          <textarea v-model="jobForm.notes"></textarea>
        </label>
        <div class="actions">
          <button class="primary" type="submit">Create commission</button>
          <button type="button" @click="showCommission = false">Cancel</button>
        </div>
      </form>
    </div>
  </div>
</template>
