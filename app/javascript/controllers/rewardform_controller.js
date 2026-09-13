import { Controller } from "@hotwired/stimulus"

// Keep the reward "Giá trị / Đơn vị" fields consistent with the chosen type so
// a % discount can't be entered as a VND amount by mistake.
export default class extends Controller {
  static targets = ["kind", "unit", "value", "valueLabel"]
  static values = {
    vndLabel: String, percentLabel: String, itemLabel: String,
    vndPh: String, percentPh: String, itemPh: String,
  }

  connect() { this.syncLabel() }

  kindChanged() {
    const k = this.kindTarget.value
    if (k === "discount") this.unitTarget.value = "percent"
    else if (k === "voucher") this.unitTarget.value = "vnd"
    else if (k === "gift") this.unitTarget.value = "item"
    this.syncLabel()
  }

  syncLabel() {
    const map = {
      vnd:     [this.vndLabelValue, this.vndPhValue],
      percent: [this.percentLabelValue, this.percentPhValue],
      item:    [this.itemLabelValue, this.itemPhValue],
    }
    const [label, ph] = map[this.unitTarget.value] || [this.vndLabelValue, ""]
    if (label && this.hasValueLabelTarget) this.valueLabelTarget.textContent = label
    if (this.hasValueTarget) this.valueTarget.placeholder = ph || ""
  }
}
