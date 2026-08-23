<script setup>
import { computed, onMounted, reactive, ref } from "vue"
import * as api from "./api.js"

const columns = ref({})
const clients = ref([])
const states = ref({})
const profile = ref({ name: "", headline: "", summary: "", skills: [] })
const error = ref("")
const selectedId = ref(null)
const showClient = ref(false)
const showCommission = ref(false)
const showProfile = ref(false)
const overState = ref("")
const careersUrl = ref("")
const careers = ref(null)
const savingKey = ref("")

const filters = reactive({ query: "", client: "", dueSoon: false, minMatch: "" })
const clientForm = reactive({ name: "", note: "" })
const jobForm = reactive({ title: "", client_id: "", state: "saved", due_on: "", listing: "", notes: "" })
const edit = reactive({ title: "", client_id: "", due_on: "", notes: "", listing: "", state: "" })
const assetForm = reactive({ label: "", url: "" })
const profileForm = reactive({ name: "", headline: "", summary: "", skills: "" })

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

function matchTone(score) {
  if (score == null) return "none"
  if (score >= 60) return "high"
  if (score >= 35) return "mid"
  return "low"
}

function matchLabel(item) {
  if (!item.match || item.match.score == null) return "No listing yet"
  return `${item.match.score}% match`
}

async function refresh() {
  const data = await api.loadBoard(filters)
  columns.value = data.columns
  clients.value = data.clients
  states.value = data.states
  profile.value = data.profile
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

function jobKey(job) {
  return `${job.company}::${job.title}`
}

async function lookupCareers() {
  await run(async () => {
    careers.value = await api.lookupCareers(careersUrl.value)
  })
}

async function saveCareer(job) {
  savingKey.value = jobKey(job)
  await run(async () => {
    await api.importCareer({
      company: job.company,
      title: job.title,
      listing: job.listing,
      url: job.url,
      location: job.location
    })
  })
  savingKey.value = ""
}

function open(item) {
  selectedId.value = item.id
  edit.title = item.title
  edit.client_id = String(item.client.id)
  edit.due_on = item.due_on || ""
  edit.notes = item.notes
  edit.listing = item.listing || ""
  edit.state = item.state
  assetForm.label = ""
  assetForm.url = ""
}

function close() {
  selectedId.value = null
}

function openProfile() {
  profileForm.name = profile.value.name || ""
  profileForm.headline = profile.value.headline || ""
  profileForm.summary = profile.value.summary || ""
  profileForm.skills = (profile.value.skills || []).join(", ")
  showProfile.value = true
}

async function saveProfile() {
  await run(async () => {
    await api.updateProfile({
      name: profileForm.name,
      headline: profileForm.headline,
      summary: profileForm.summary,
      skills: profileForm.skills.split(",").map((skill) => skill.trim()).filter(Boolean)
    })
    showProfile.value = false
  })
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
      listing: jobForm.listing,
      notes: jobForm.notes
    })
    jobForm.title = ""
    jobForm.due_on = ""
    jobForm.listing = ""
    jobForm.notes = ""
    jobForm.state = "saved"
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
      listing: edit.listing,
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

    <section class="profile-bar">
      <div>
        <p class="eyebrow">Your profile</p>
        <p class="lede">{{ profile.headline || "Add the skills you want a role to mention." }}</p>
        <p class="skills">
          <span v-for="skill in profile.skills" :key="skill">{{ skill }}</span>
          <span v-if="!profile.skills.length" class="muted">No skills yet.</span>
        </p>
      </div>
      <button type="button" @click="openProfile">Edit profile</button>
    </section>

    <section class="careers">
      <form @submit.prevent="lookupCareers">
        <h2>Check a careers link</h2>
        <p class="hint">Greenhouse, Lever, Ashby, Workable, or SmartRecruiters. Folio calls their public job APIs, then scores each role against your skills.</p>
        <label>
          Careers URL
          <input v-model="careersUrl" type="url" required placeholder="https://boards.greenhouse.io/company">
        </label>
        <button class="primary" type="submit">Check board</button>
      </form>
      <div v-if="careers" class="career-list">
        <p class="eyebrow">{{ careers.company }} · {{ careers.source }} · {{ careers.jobs.length }} roles</p>
        <article v-for="job in careers.jobs" :key="jobKey(job)" class="career-row">
          <div>
            <strong>{{ job.title }}</strong>
            <p class="muted">{{ job.location || "Location not listed" }}</p>
            <p class="match" :class="matchTone(job.match?.score)">{{ job.match?.score == null ? "No skill overlap" : `${job.match.score}% match` }}</p>
            <p v-if="job.match?.hits?.length" class="hint">Fits: {{ job.match.hits.join(", ") }}</p>
            <p v-if="job.match?.gaps?.length" class="hint">Missing: {{ job.match.gaps.join(", ") }}</p>
          </div>
          <div class="actions">
            <a v-if="job.url" class="button" :href="job.url" target="_blank" rel="noreferrer">Open</a>
            <button class="primary" type="button" :disabled="savingKey === jobKey(job)" @click="saveCareer(job)">Save to board</button>
          </div>
        </article>
      </div>
    </section>

    <div class="toolbar">
      <form class="toolbar" @submit.prevent="applyFilters">
        <label>
          Filter
          <input v-model="filters.query" type="text" autocomplete="off" placeholder="Title, company, or listing">
        </label>
        <label>
          Company
          <select v-model="filters.client">
            <option value="">All companies</option>
            <option v-for="client in clients" :key="client.id" :value="client.slug">{{ client.name }}</option>
          </select>
        </label>
        <label>
          Min match
          <input v-model="filters.minMatch" type="number" min="0" max="100" placeholder="0">
        </label>
        <label class="check">
          <input v-model="filters.dueSoon" type="checkbox">
          Due in 14 days
        </label>
        <button class="primary" type="submit">Filter</button>
      </form>
      <div class="actions">
        <button type="button" @click="showClient = true">New company</button>
        <button class="primary" type="button" @click="showCommission = true">New role</button>
      </div>
    </div>

    <section class="board" aria-label="Role board">
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
          <span class="match" :class="matchTone(item.match?.score)">{{ matchLabel(item) }}</span>
          <span v-if="item.due_on" class="muted due" :class="{ soon: dueSoon(item.due_on) }">Due {{ item.due_on }}</span>
        </button>
      </article>
    </section>

    <div v-if="selected" class="drawer-back" @click="close"></div>
    <aside v-if="selected" class="drawer" role="dialog" aria-labelledby="job-title">
      <p class="eyebrow">{{ states[selected.state] }}</p>
      <h2 id="job-title">{{ selected.title }}</h2>
      <p class="muted">{{ selected.client.name }}</p>
      <p class="match" :class="matchTone(selected.match?.score)">{{ matchLabel(selected) }}</p>
      <p v-if="selected.match?.hits?.length" class="hint">Fits: {{ selected.match.hits.join(", ") }}</p>
      <p v-if="selected.match?.gaps?.length" class="hint">Missing: {{ selected.match.gaps.join(", ") }}</p>
      <p v-if="selected.match?.score == null" class="hint">Paste the job description to score this role.</p>

      <label>
        Title
        <input v-model="edit.title" type="text">
      </label>
      <label>
        Company
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
        Job description
        <textarea v-model="edit.listing" placeholder="Paste the listing. Matching reads this, not your notes."></textarea>
      </label>
      <label>
        Notes
        <textarea v-model="edit.notes" placeholder="Why you applied. Markdown is fine."></textarea>
      </label>
      <div class="actions">
        <button class="primary" type="button" @click="saveEdit">Save</button>
        <button class="danger" type="button" @click="removeJob">Delete</button>
        <button type="button" @click="close">Close</button>
      </div>

      <h3 class="eyebrow" style="margin-top: 1.4rem">Note</h3>
      <div class="notes" v-html="selected.notes_html || '<p class=&quot;muted&quot;>No note yet.</p>'"></div>

      <h3 class="eyebrow">Links</h3>
      <ul class="assets">
        <li v-for="asset in selected.assets" :key="asset.id">
          <a :href="asset.url" target="_blank" rel="noreferrer">{{ asset.label }}</a>
          <button type="button" class="danger" @click="removeAsset(asset.id)">Remove</button>
        </li>
      </ul>
      <label>
        Label
        <input v-model="assetForm.label" type="text" placeholder="Posting">
      </label>
      <label>
        URL
        <input v-model="assetForm.url" type="url" placeholder="https://">
      </label>
      <button type="button" @click="saveAsset">Add link</button>
    </aside>

    <div v-if="showProfile" class="modal" @click.self="showProfile = false">
      <form class="panel" @submit.prevent="saveProfile">
        <h2>Profile</h2>
        <label>
          Name
          <input v-model="profileForm.name" type="text" autocomplete="off">
        </label>
        <label>
          Headline
          <input v-model="profileForm.headline" type="text" autocomplete="off">
        </label>
        <label>
          Summary
          <textarea v-model="profileForm.summary" placeholder="What you want a role to see."></textarea>
        </label>
        <label>
          Skills
          <input v-model="profileForm.skills" type="text" autocomplete="off" placeholder="Rails, Vue, Go">
        </label>
        <p class="hint">Comma-separated. Matching looks for these words in a listing.</p>
        <div class="actions">
          <button class="primary" type="submit">Save profile</button>
          <button type="button" @click="showProfile = false">Cancel</button>
        </div>
      </form>
    </div>

    <div v-if="showClient" class="modal" @click.self="showClient = false">
      <form class="panel" @submit.prevent="saveClient">
        <h2>New company</h2>
        <label>
          Name
          <input v-model="clientForm.name" type="text" required autocomplete="off">
        </label>
        <label>
          Note
          <textarea v-model="clientForm.note" placeholder="What they hire for."></textarea>
        </label>
        <div class="actions">
          <button class="primary" type="submit">Create company</button>
          <button type="button" @click="showClient = false">Cancel</button>
        </div>
      </form>
    </div>

    <div v-if="showCommission" class="modal" @click.self="showCommission = false">
      <form class="panel" @submit.prevent="saveCommission">
        <h2>New role</h2>
        <label>
          Title
          <input v-model="jobForm.title" type="text" required autocomplete="off">
        </label>
        <label>
          Company
          <select v-model="jobForm.client_id" required>
            <option disabled value="">Choose a company</option>
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
          Job description
          <textarea v-model="jobForm.listing" placeholder="Paste the listing."></textarea>
        </label>
        <label>
          Notes
          <textarea v-model="jobForm.notes"></textarea>
        </label>
        <div class="actions">
          <button class="primary" type="submit">Create role</button>
          <button type="button" @click="showCommission = false">Cancel</button>
        </div>
      </form>
    </div>
  </div>
</template>
