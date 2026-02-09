import {Socket} from "phoenix"

export function initSimulationCanvas() {
  const canvas = document.getElementById("simulation-canvas")
  if (!canvas) return

  const ctx = canvas.getContext("2d")
  const simulationId = canvas.dataset.simulationId

  const socket = new Socket("/socket", {})
  socket.connect()

  const channel = socket.channel(`simulation:${simulationId}`, {})

  channel.on("positions", ({positions}) => {
    ctx.clearRect(0, 0, canvas.width, canvas.height)

    ctx.fillStyle = "red"
    positions.forEach(p => {
      ctx.beginPath()
      ctx.arc(p.x, p.y, 20, 0, 2 * Math.PI)
      ctx.strokeStyle = "blue"
      ctx.lineWidth = 2
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
