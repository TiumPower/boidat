import { Controller } from "@hotwired/stimulus"

// Add / remove rows in the "required documents" settings form.
export default class extends Controller {
  static targets = ["template"]

  add() {
    const idx = Date.now() // unique index so params don't collide
    const html = this.templateTarget.innerHTML.replaceAll("NEW_INDEX", idx)
    const frag = document.createRange().createContextualFragment(html)
    this.templateTarget.parentNode.appendChild(frag)
  }

  remove(event) {
    event.target.closest(".doc-row")?.remove()
  }
}
