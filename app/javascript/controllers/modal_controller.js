import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("turbo:frame-load", this.open.bind(this))
  }

  open() {
    const frame = this.element.querySelector("turbo-frame")
    if (!frame || frame.innerHTML.trim() === "") return

    this.element.classList.remove("hidden")
    this.element.classList.add("flex")
  }

  close() {
    this.element.classList.add("hidden")
    this.element.classList.remove("flex")

    const frame = this.element.querySelector("turbo-frame")
    if (frame) frame.innerHTML = ""
  }

  backdropClick(event) {
    if (event.target === this.element) this.close()
  }

  keydown(event) {
    if (event.key === "Escape") this.close()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }
}
