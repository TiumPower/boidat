import { Controller } from "@hotwired/stimulus"

// Filter the "start a new chat" room list by a search box.
export default class extends Controller {
  static targets = ["q", "item"]

  filter() {
    const q = this.qTarget.value.trim().toLowerCase()
    this.itemTargets.forEach((el) => {
      el.hidden = q.length > 0 && !(el.dataset.name || "").includes(q)
    })
  }
}
