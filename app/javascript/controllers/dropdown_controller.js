import { Controller } from "@hotwired/stimulus"

// A click-to-toggle menu — click the button to open/close, click anywhere
// outside, press Escape, or click a menu item to close. Used for the
// header's "Settings" menu (TASK-062); generic enough to reuse elsewhere.
export default class extends Controller {
  static targets = [ "menu" ]

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")
  }

  close() {
    this.menuTarget.classList.add("hidden")
  }

  // Bound to click@window — anything outside this controller's own element
  // closes the menu, including a click on some other page control.
  outsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  keydown(event) {
    if (event.key === "Escape") this.close()
  }
}
