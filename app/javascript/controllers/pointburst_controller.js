import { Controller } from "@hotwired/stimulus"

// A light confetti burst for reward/success moments.
export default class extends Controller {
  connect() {
    const colors = ["#E0B54A", "#E08A3C", "#3F7A57", "#C64B8C", "#4B9FE1"]
    for (let i = 0; i < 26; i++) {
      const p = document.createElement("span")
      const size = 6 + Math.random() * 6
      Object.assign(p.style, {
        position: "fixed", left: "50%", top: "30%", width: `${size}px`, height: `${size}px`,
        background: colors[i % colors.length], borderRadius: Math.random() > 0.5 ? "50%" : "2px",
        pointerEvents: "none", zIndex: 9999, opacity: "1",
      })
      document.body.appendChild(p)
      const dx = (Math.random() - 0.5) * 320
      const dy = 120 + Math.random() * 260
      const rot = (Math.random() - 0.5) * 720
      p.animate(
        [{ transform: "translate(0,0) rotate(0)", opacity: 1 },
         { transform: `translate(${dx}px, ${dy}px) rotate(${rot}deg)`, opacity: 0 }],
        { duration: 900 + Math.random() * 700, easing: "cubic-bezier(.2,.7,.3,1)" }
      ).onfinish = () => p.remove()
    }
  }
}
