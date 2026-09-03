import { Controller } from "@hotwired/stimulus"

// A convenience alternative to typing start/end dates directly: picking a
// "from" and/or "to" sprint fills the same date fields with that sprint's
// start/end date. Purely client-side — these selects are never submitted,
// they just write into the real date inputs next to them.
export default class extends Controller {
  static targets = [ "fromSelect", "toSelect", "startInput", "endInput" ]

  apply() {
    if (this.fromSelectTarget.value) this.startInputTarget.value = this.fromSelectTarget.value
    if (this.toSelectTarget.value) this.endInputTarget.value = this.toSelectTarget.value
  }
}
