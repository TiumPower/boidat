import { Controller } from "@hotwired/stimulus"

// Repeatable service-fee rows. Row inputs are named fees[N][label] /
// fees[N][amount]; N is re-sequenced after every add/remove so the server
// always receives a dense list.
export default class extends Controller {
  static targets = ["rows", "row", "template"]
  static values = { field: { type: String, default: "fees" } }

  add() {
    const html = this.templateTarget.innerHTML.replace(/IDX/g, String(this.rowTargets.length))
    this.rowsTarget.insertAdjacentHTML("beforeend", html)
    this.rowsTarget.querySelector(".fee-row:last-child input")?.focus()
  }

  remove(e) {
    e.currentTarget.closest(".fee-row").remove()
    this.#reindex()
  }

  #reindex() {
    this.rowTargets.forEach((row, i) => {
      row.querySelectorAll("input").forEach((input) => {
        input.name = input.name.replace(/^[^\[]+\[\d+\]/, `${this.fieldValue}[${i}]`)
      })
    })
  }
}
