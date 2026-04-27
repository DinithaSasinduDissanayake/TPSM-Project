const slides = Array.from(document.querySelectorAll(".slide"))
const counter = document.querySelector("#counter")
const prev = document.querySelector("#prev")
const next = document.querySelector("#next")

let current = Number.parseInt(location.hash.replace("#", ""), 10) - 1
if (!Number.isInteger(current) || current < 0 || current >= slides.length) current = 0

function show(index) {
  current = Math.max(0, Math.min(index, slides.length - 1))
  slides.forEach((slide, i) => slide.classList.toggle("active", i === current))
  counter.textContent = `${current + 1} / ${slides.length}`
  history.replaceState(null, "", `#${current + 1}`)
}

prev.addEventListener("click", () => show(current - 1))
next.addEventListener("click", () => show(current + 1))

window.addEventListener("keydown", (event) => {
  if (["ArrowRight", "PageDown", " "].includes(event.key)) show(current + 1)
  if (["ArrowLeft", "PageUp"].includes(event.key)) show(current - 1)
  if (event.key === "Home") show(0)
  if (event.key === "End") show(slides.length - 1)
})

show(current)
