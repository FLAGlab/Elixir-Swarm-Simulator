import {Socket} from "phoenix"

export function initSimulationCanvas() {
  const canvas = document.getElementById("simulation-canvas")
  if (!canvas) return

  const ctx = canvas.getContext("2d")
  const simulationId = canvas.dataset.simulationId

  const socket = new Socket("/socket", {})
  socket.connect()

  const channel = socket.channel(`simulation:${simulationId}`, {})

  function getThemeColors() {
    const style = getComputedStyle(document.documentElement)
    return {
      fill: style.getPropertyValue("--color-primary").trim() || "#6366f1",
      stroke: style.getPropertyValue("--color-secondary").trim() || "#8b5cf6"
    }
  }

  channel.on("positions", ({positions}) => {
    ctx.clearRect(0, 0, canvas.width, canvas.height)

    const colors = getThemeColors()
    ctx.fillStyle = colors.fill
    ctx.strokeStyle = colors.stroke
    ctx.lineWidth = 2
    positions.forEach(p => {
      ctx.beginPath()
      ctx.arc(p.x, p.y, 20, 0, 2 * Math.PI)
      ctx.stroke()
      ctx.beginPath()
      ctx.arc(p.x, p.y, 5, 0, 2 * Math.PI)
      ctx.fill()
    })
  })

  channel.join()
    .receive("ok", () => console.log("Joined simulation channel"))
    .receive("error", ({reason}) => console.error("Failed to join", reason))
}
