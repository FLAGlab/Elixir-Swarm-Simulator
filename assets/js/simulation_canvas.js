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
    alone:        { fill: "#6366f1", stroke: "#8b5cf6" },
    neighbor:     { fill: "#22c55e", stroke: "#16a34a" },
    selected:     { fill: "#f59e0b", stroke: "#d97706" },
    disconnected: { fill: "#9ca3af", stroke: "#6b7280" }
  }

  let selectedDroneId = null
  let currentOverlay = null
  let objectivePosition = null
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

  // --- Objective ---

  function drawObjective() {
    if (!objectivePosition) return

    ctx.save()
    ctx.strokeStyle = "#ef4444"
    ctx.fillStyle = "#ef4444"
    ctx.lineWidth = 2

    ctx.beginPath()
    ctx.arc(objectivePosition.x, objectivePosition.y, 15, 0, 2 * Math.PI)
    ctx.stroke()

    ctx.beginPath()
    ctx.arc(objectivePosition.x, objectivePosition.y, 6, 0, 2 * Math.PI)
    ctx.fill()
    ctx.restore()
  }

  // --- Drone grid ---

  const droneGrid = document.getElementById("drone-grid")
  const droneSearch = document.getElementById("drone-search")
  const maxSlots = 12
  let searchFilter = ""

  // Search input: filter grid as user types
  if (droneSearch) {
    droneSearch.addEventListener("input", (e) => {
      searchFilter = e.target.value.trim()
      if (lastPositions) updateDroneGrid(lastPositions)
    })
  }

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
  let lastPositions = null

  function updateDroneGrid(positions) {
    if (!droneGrid) return

    lastPositions = positions

    const sorted = [...positions].sort((a, b) => a.id - b.id)

    // Apply search filter
    const filtered = searchFilter
      ? sorted.filter(p => String(p.id).includes(searchFilter))
      : sorted

    const total = filtered.length
    const visible = total <= maxSlots ? filtered : filtered.slice(0, maxSlots - 1)
    const remaining = total - visible.length

    // Only rebuild DOM when the drone list changes
    const currentIds = visible.map(p => p.id).join(",") + (remaining > 0 ? `,+${remaining}` : "") + `|${searchFilter}`
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

      const isDisconnected = p.disconnected === true
      const colors = isDisconnected ? agentColors.disconnected : (agentColors[p.color] || agentColors.alone)
      const dot = cell.querySelector(".drone-color")
      if (dot) dot.style.background = colors.fill

      const isSelected = p.id === selectedDroneId
      const opacity = isDisconnected && !isSelected ? " opacity-40" : ""
      cell.className = `flex items-center gap-2 px-3 py-2 rounded-lg text-sm font-mono cursor-pointer transition-colors ${isSelected ? "bg-primary text-primary-content" : "bg-base-300 hover:bg-base-200"}${opacity}`
    })
  }

  // --- Detail panel ---

  const detailPanel = document.getElementById("drone-detail")
  let lastDetailDroneId = null

  // Event delegation for the toggle button (set up once, uses mousedown
  // to avoid losing the click when innerHTML is rebuilt every ~30ms)
  if (detailPanel) {
    detailPanel.addEventListener("mousedown", (e) => {
      const btn = e.target.closest("#drone-toggle-conn")
      if (!btn || lastDetailDroneId == null) return

      e.preventDefault()
      const isDisconnected = btn.dataset.disconnected === "true"
      currentChannel.push("toggle_drone_connection", {
        id: lastDetailDroneId,
        connected: isDisconnected  // if disconnected, send true to reconnect
      })
    })
  }

  function updateDetailPanel(detail) {
    if (!detailPanel) return

    if (!detail) {
      detailPanel.innerHTML = ""
      return
    }

    const colors = agentColors[detail.color] || agentColors.alone
    const fields = (detail.algorithm_state || {}).detail_fields || []

    let algoHtml = ""
    if (fields.length > 0) {
      const rows = fields.map(field => {
        let display
        switch (field.type) {
          case "position":
            display = `(${field.value.x}, ${field.value.y})`
            break
          case "badge":
            display = `<span class="badge badge-outline badge-sm">${field.value}</span>`
            break
          case "boolean":
            display = field.value ? "Yes" : "No"
            break
          default:
            display = String(field.value)
        }
        return `<div class="flex justify-between"><span class="text-base-content/60">${field.label}</span><span class="font-mono">${display}</span></div>`
      }).join("")
      algoHtml = `<div class="mt-2 pt-2 border-t border-base-content/10 space-y-1">${rows}</div>`
    }

    const isDisconnected = detail.disconnected === true
    lastDetailDroneId = detail.id

    const statusBadge = isDisconnected
      ? `<span class="badge badge-error badge-sm">Disconnected</span>`
      : `<span class="badge badge-success badge-sm">Connected</span>`

    const toggleBtn = isDisconnected
      ? `<button id="drone-toggle-conn" data-disconnected="true" class="btn btn-success btn-sm w-full mt-2">Reconnect</button>`
      : `<button id="drone-toggle-conn" data-disconnected="false" class="btn btn-error btn-sm w-full mt-2">Disconnect</button>`

    detailPanel.innerHTML = `
      <div class="rounded-lg bg-base-300 p-4 space-y-2">
        <div class="flex items-center gap-2 font-bold">
          <span class="inline-block w-3 h-3 rounded-full" style="background:${colors.fill}"></span>
          Drone ${detail.id}
          ${statusBadge}
        </div>
        <div class="grid grid-cols-2 gap-x-4 gap-y-1 text-sm">
          <div class="flex justify-between"><span class="text-base-content/60">Position</span><span class="font-mono">(${detail.position.x}, ${detail.position.y})</span></div>
          <div class="flex justify-between"><span class="text-base-content/60">Neighbors</span><span class="font-mono">${detail.neighbors_count}</span></div>
        </div>
        ${algoHtml}
        ${toggleBtn}
      </div>`
  }

  // --- Channel events ---

  currentChannel.on("positions", ({positions, objective}) => {
    if (objective) objectivePosition = objective

    ctx.clearRect(0, 0, canvas.width, canvas.height)

    drawStructures()
    drawOverlay()
    drawObjective()

    ctx.lineWidth = 2
    positions.forEach(p => {
      const isSelected = p.id === selectedDroneId
      const isDisconnected = p.disconnected === true

      let colors
      if (isSelected) colors = agentColors.selected
      else if (isDisconnected) colors = agentColors.disconnected
      else colors = agentColors[p.color] || agentColors.alone

      ctx.save()
      if (isDisconnected && !isSelected) ctx.globalAlpha = 0.4

      ctx.strokeStyle = colors.stroke
      ctx.fillStyle = colors.fill
      ctx.beginPath()
      ctx.arc(p.x, p.y, 20, 0, 2 * Math.PI)
      ctx.stroke()
      ctx.beginPath()
      ctx.arc(p.x, p.y, 5, 0, 2 * Math.PI)
      ctx.fill()
      ctx.restore()
    })

    updateDroneGrid(positions)
  })

  currentChannel.on("drone_detail", (detail) => {
    const algo = detail.algorithm_state || {}
    currentOverlay = algo.overlay || null
    updateDetailPanel(detail)
  })

  currentChannel.on("simulation_complete", ({execution_run_id}) => {
    setTimeout(() => {
      window.location.href = `/execution_runs/${execution_run_id}`
    }, 1500)
  })

  currentChannel.join()
    .receive("ok", () => console.log("Joined simulation channel"))
    .receive("error", ({reason}) => console.error("Failed to join", reason))
}
