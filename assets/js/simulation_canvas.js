import {Socket} from "phoenix"

let currentSocket = null
let currentChannel = null

export function initSimulationCanvas() {
  const canvas = document.getElementById("simulation-canvas")
  if (!canvas) return

  // Avoid duplicate connections if called multiple times
  if (canvas.dataset.initialized) return
  canvas.dataset.initialized = "true"

  // Clean up previous connection if navigating between executions
  if (currentChannel) {
    currentChannel.leave()
    currentChannel = null
  }
  if (currentSocket) {
    currentSocket.disconnect()
    currentSocket = null
  }

  const ctx = canvas.getContext("2d")
  const simulationId = canvas.dataset.simulationId
  const structures = JSON.parse(canvas.dataset.structures || "[]")

  currentSocket = new Socket("/socket", {})
  currentSocket.connect()

  currentChannel = currentSocket.channel(`simulation:${simulationId}`, {})

  function getThemeColors() {
    const style = getComputedStyle(document.documentElement)
    return {
      fill: style.getPropertyValue("--color-primary").trim() || "#6366f1",
      stroke: style.getPropertyValue("--color-secondary").trim() || "#8b5cf6"
    }
  }

  function drawStructures(ctx, structures) {
    ctx.save()
    ctx.fillStyle = "rgba(128, 128, 128, 0.3)"
    ctx.strokeStyle = "rgba(128, 128, 128, 0.8)"
    ctx.lineWidth = 2

    structures.forEach(structure => {
      if (!structure.points || structure.points.length === 0) return

      ctx.beginPath()
      ctx.moveTo(structure.points[0].x, structure.points[0].y)
      for (let i = 1; i < structure.points.length; i++) {
        ctx.lineTo(structure.points[i].x, structure.points[i].y)
      }
      ctx.closePath()
      ctx.fill()
      ctx.stroke()
    })

    ctx.restore()
  }

  currentChannel.on("positions", ({positions}) => {
    ctx.clearRect(0, 0, canvas.width, canvas.height)

    // Draw structures behind agents
    drawStructures(ctx, structures)

    // Draw agents
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

  currentChannel.join()
    .receive("ok", () => console.log("Joined simulation channel"))
    .receive("error", ({reason}) => console.error("Failed to join", reason))
}
