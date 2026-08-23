function csrf() {
  return document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
}

async function request(url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "X-CSRF-Token": csrf(),
      ...(options.headers || {})
    }
  })
  const data = await response.json().catch(() => ({}))
  if (!response.ok) {
    throw new Error(data.error || `Request failed (${response.status})`)
  }
  return data
}

export function loadBoard(filters) {
  const params = new URLSearchParams()
  if (filters.query) params.set("q", filters.query)
  if (filters.client) params.set("client", filters.client)
  if (filters.dueSoon) params.set("due", "soon")
  if (filters.minMatch) params.set("min", filters.minMatch)
  const query = params.toString()
  return request(`/api/board${query ? `?${query}` : ""}`)
}

export function lookupCareers(url) {
  return request("/api/careers/lookup", { method: "POST", body: JSON.stringify({ url }) })
}

export function importCareer(payload) {
  return request("/api/careers/import", { method: "POST", body: JSON.stringify(payload) })
}

export function updateProfile(payload) {
  return request("/api/profile", { method: "PATCH", body: JSON.stringify(payload) })
}

export function createClient(payload) {
  return request("/api/clients", { method: "POST", body: JSON.stringify(payload) })
}

export function createCommission(payload) {
  return request("/api/commissions", { method: "POST", body: JSON.stringify(payload) })
}

export function updateCommission(id, payload) {
  return request(`/api/commissions/${id}`, { method: "PATCH", body: JSON.stringify(payload) })
}

export function moveCommission(id, state) {
  return request(`/api/commissions/${id}/move`, { method: "POST", body: JSON.stringify({ state }) })
}

export function deleteCommission(id) {
  return request(`/api/commissions/${id}`, { method: "DELETE" })
}

export function addAsset(commissionId, payload) {
  return request(`/api/commissions/${commissionId}/assets`, {
    method: "POST",
    body: JSON.stringify(payload)
  })
}

export function deleteAsset(id) {
  return request(`/api/assets/${id}`, { method: "DELETE" })
}
