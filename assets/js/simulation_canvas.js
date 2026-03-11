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

  const agentColors = {
    alone:    { fill: "#6366f1", stroke: "#8b5cf6" },
    neighbor: { fill: "#22c55e", stroke: "#16a34a" },
    selected: { fill: "#f59e0b", stroke: "#d97706" }
  }

  let selectedDroneId = null
  let currentOverlay = null
  const cellSize = 20

  // --- Structures ---

  function drawStructures() {
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

  // --- Cell overlay ---

  function drawOverlay() {
    if (!currentOverlay) return

    const {cells, color} = currentOverlay
    if (!cells || cells.length === 0) return

    ctx.save()
    cells.forEach(({x, y, intensity}) => {
      ctx.fillStyle = `rgba(${color}, ${0.1 + intensity * 0.5})`
      ctx.fillRect(x, y, cellSize, cellSize)
    })
    ctx.restore()
  }

  function buildHeatmapOverlay(visited) {
    const grid = {}
    visited.forEach(pos => {
      const col = Math.floor(pos.x / cellSize)
      const row = Math.floor(pos.y / cellSize)
      const key = `${col},${row}`
      grid[key] = (grid[key] || 0) + 1
    })

    const counts = Object.values(grid)
    const maxCount = Math.max(...counts)
    if (maxCount === 0) return null

    const cells = Object.entries(grid).map(([key, count]) => {
      const [col, row] = key.split(",").map(Number)
      return {x: col * cellSize, y: row * cellSize, intensity: count / maxCount}
    })

    return {cells, color: "239, 68, 68"}
  }

  // --- Drone grid ---

  const droneGrid = document.getElementById("drone-grid")
  const maxSlots = 12

  // Event delegation: single listener on the grid container
  if (droneGrid) {
    droneGrid.addEventListener("click", (e) => {
      const cell = e.target.closest("[data-drone-id]")
      if (!cell) return

      const id = parseInt(cell.dataset.droneId, 10)
      if (selectedDroneId === id) {
        selectedDroneId = null
        currentOverlay = null
        currentChannel.push("deselect_drone", {})
        updateDetailPanel(null)
      } else {
        selectedDroneId = id
        currentChannel.push("select_drone", {id})
      }
    })
  }

  let knownDroneIds = []

  function updateDroneGrid(positions) {
    if (!droneGrid) return

    const sorted = [...positions].sort((a, b) => a.id - b.id)
    const total = sorted.length
    const visible = total <= maxSlots ? sorted : sorted.slice(0, maxSlots - 1)
    const remaining = total - visible.length

    // Only rebuild DOM when the drone list changes
    const currentIds = visible.map(p => p.id).join(",") + (remaining > 0 ? `,+${remaining}` : "")
    const needsRebuild = currentIds !== knownDroneIds

    if (needsRebuild) {
      knownDroneIds = currentIds
      droneGrid.innerHTML = ""

      visible.forEach(p => {
        const cell = document.createElement("div")
        cell.dataset.droneId = p.id
        cell.className = "flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-mono cursor-pointer transition-colors bg-base-300 hover:bg-base-200"
        cell.innerHTML = `<span class="drone-color inline-block w-3 h-3 rounded-full"></span> Drone ${p.id}`
        droneGrid.appendChild(cell)
      })

      if (remaining > 0) {
        const cell = document.createElement("div")
        cell.className = "flex items-center justify-center px-3 py-2 rounded-lg bg-base-300 text-sm font-mono text-base-content/60"
        cell.textContent = `+${remaining} more`
        droneGrid.appendChild(cell)
      }
    }

    // Update colors and selection styles without rebuilding
    visible.forEach(p => {
      const cell = droneGrid.querySelector(`[data-drone-id="${p.id}"]`)
      if (!cell) return

      const colors = agentColors[p.color] || agentColors.alone
      const dot = cell.querySelector(".drone-color")
      if (dot) dot.style.background = colors.fill

      const isSelected = p.id === selectedDroneId
      cell.className = `flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-mono cursor-pointer transition-colors ${isSelected ? "bg-primary text-primary-content" : "bg-base-300 hover:bg-base-200"}`
    })
  }

  // --- Detail panel ---

  const detailPanel = document.getElementById("drone-detail")

  function updateDetailPanel(detail) {
    if (!detailPanel) return

    if (!detail) {
      detailPanel.innerHTML = ""
      return
    }

    const colors = agentColors[detail.color] || agentColors.alone
    const algoEntries = Object.entries(detail.algorithm_state || {})
      .filter(([key]) => key !== "visited" && key !== "pheromone_overlay")

    let algoHtml = ""
    if (algoEntries.length > 0) {
      const rows = algoEntries.map(([key, value]) => {
        const display = typeof value === "object" ? JSON.stringify(value) : value
        return `<div class="flex justify-between"><span class="text-base-content/60">${key}</span><span class="font-mono">${display}</span></div>`
      }).join("")
      algoHtml = `<div class="mt-2 pt-2 border-t border-base-content/10 space-y-1">${rows}</div>`
    }

    detailPanel.innerHTML = `
      <div class="rounded-lg bg-base-300 p-4 space-y-2">
        <div class="flex items-center gap-2 font-bold">
          <span class="inline-block w-3 h-3 rounded-full" style="background:${colors.fill}"></span>
          Drone ${detail.id}
        </div>
        <div class="grid grid-cols-2 gap-x-4 gap-y-1 text-sm">
          <div class="flex justify-between"><span class="text-base-content/60">Position</span><span class="font-mono">(${detail.position.x}, ${detail.position.y})</span></div>
          <div class="flex justify-between"><span class="text-base-content/60">Neighbors</span><span class="font-mono">${detail.neighbors_count}</span></div>
        </div>
        ${algoHtml}
      </div>`
  }

  // --- Channel events ---

  currentChannel.on("positions", ({positions}) => {
    ctx.clearRect(0, 0, canvas.width, canvas.height)

    drawStructures()
    drawOverlay()

    ctx.lineWidth = 2
    positions.forEach(p => {
      const isSelected = p.id === selectedDroneId
      const colors = isSelected ? agentColors.selected : (agentColors[p.color] || agentColors.alone)
      ctx.strokeStyle = colors.stroke
      ctx.fillStyle = colors.fill
      ctx.beginPath()
      ctx.arc(p.x, p.y, 20, 0, 2 * Math.PI)
      ctx.stroke()
      ctx.beginPath()
      ctx.arc(p.x, p.y, 5, 0, 2 * Math.PI)
      ctx.fill()
    })

    updateDroneGrid(positions)
  })

  currentChannel.on("drone_detail", (detail) => {
    const algo = detail.algorithm_state || {}

    if (algo.visited) {
      currentOverlay = buildHeatmapOverlay(algo.visited)
    } else if (algo.pheromone_overlay) {
      currentOverlay = {cells: algo.pheromone_overlay, color: "59, 130, 246"}
    } else {
      currentOverlay = null
    }

    updateDetailPanel(detail)
  })

  currentChannel.join()
    .receive("ok", () => console.log("Joined simulation channel"))
    .receive("error", ({reason}) => console.error("Failed to join", reason))
}
