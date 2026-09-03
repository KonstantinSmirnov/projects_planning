import { Controller } from "@hotwired/stimulus"

// Saves the milestone/task detail overlay's form in place — no page reload,
// no full-page redirect — then closes the overlay itself. TASK-051: this
// replaces the old `data-turbo-frame: "_top"` full-page redirect, which
// closed the overlay by tearing down and reloading the whole page around it.
//
// The Gantt chart itself lives in a completely separate part of the page
// (this overlay is rendered into the layout's shared modal frame, not nested
// inside the Gantt controller's own element), so there's no direct Stimulus
// target/outlet relationship available — a `window` CustomEvent is how this
// reaches back to it instead (see gantt_controller.js#handleItemSaved).
export default class extends Controller {
  static targets = [ "error" ]

  save(event) {
    event.preventDefault()
    const form = event.target
    const paramKey = form.action.includes("/milestones/") ? "milestone" : "task"
    const kind = paramKey === "milestone" ? "milestones" : "tasks"
    const urlMatch = form.action.match(/\/projects\/(\d+)\/(?:tasks|milestones)\/(\d+)/)
    if (!urlMatch) return
    const [ , projectId, itemId ] = urlMatch

    const attrs = {}
    const fieldPattern = new RegExp(`^${paramKey}\\[(\\w+)\\]$`)
    new FormData(form).forEach((value, name) => {
      const match = name.match(fieldPattern)
      // Later entries win — matches how a real form submit treats duplicate
      // names, which is exactly how a Rails checkbox's hidden "0" fallback
      // and the checkbox itself (when checked) both share one name.
      if (match) attrs[match[1]] = value
    })

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(form.action, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken, Accept: "application/json" },
      body: JSON.stringify({ [paramKey]: attrs })
    })
      .then((response) => response.json().then((body) => ({ ok: response.ok, body })))
      .then(({ ok, body }) => {
        if (!ok) {
          this.showError((body.errors || []).join(", ") || "Save failed.")
          return
        }
        window.dispatchEvent(new CustomEvent("gantt:item-saved", { detail: { kind, projectId, itemId, attrs: body } }))
        this.closeModal()
      })
      .catch(() => this.showError("Save failed — check your connection and try again."))
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  closeModal() {
    const modalElement = document.querySelector('[data-controller~="modal"]')
    if (!modalElement) return
    this.application.getControllerForElementAndIdentifier(modalElement, "modal")?.close()
  }
}
