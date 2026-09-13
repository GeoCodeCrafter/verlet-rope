const canvas = document.getElementById('c')
const ctx = canvas.getContext('2d')

const GRAVITY = 0.5
const FRICTION = 0.99
const ITERATIONS = 8

const points = []
const sticks = []

function point(x, y, pinned = false) {
  const p = { x, y, ox: x, oy: y, pinned }
  points.push(p)
  return p
}

function stick(a, b) {
  const s = { a, b, len: Math.hypot(a.x - b.x, a.y - b.y) }
  sticks.push(s)
  return s
}

function rope(x, y, segments, gap) {
  let prev = point(x, y, true)
  for (let i = 1; i <= segments; i++) {
    const p = point(x + i * gap, y)
    stick(prev, p)
    prev = p
  }
}

function update() {
  for (const p of points) {
    if (p.pinned) continue
    const vx = (p.x - p.ox) * FRICTION
    const vy = (p.y - p.oy) * FRICTION
    p.ox = p.x
    p.oy = p.y
    p.x += vx
    p.y += vy + GRAVITY
  }

  for (let i = 0; i < ITERATIONS; i++) {
    for (const s of sticks) {
      const dx = s.b.x - s.a.x
      const dy = s.b.y - s.a.y
      const d = Math.hypot(dx, dy) || 0.0001
      const wa = s.a.pinned ? 0 : 1
      const wb = s.b.pinned ? 0 : 1
      if (wa + wb === 0) continue
      // push both ends back towards the rest length, pinned ends don't move
      const k = (d - s.len) / d / (wa + wb)
      s.a.x += dx * k * wa
      s.a.y += dy * k * wa
      s.b.x -= dx * k * wb
      s.b.y -= dy * k * wb
    }
  }
}

function draw() {
  ctx.fillStyle = '#16161a'
  ctx.fillRect(0, 0, canvas.width, canvas.height)

  ctx.strokeStyle = '#e8e4d8'
  ctx.lineWidth = 2
  ctx.beginPath()
  for (const s of sticks) {
    ctx.moveTo(s.a.x, s.a.y)
    ctx.lineTo(s.b.x, s.b.y)
  }
  ctx.stroke()

  ctx.fillStyle = '#ff6b4a'
  for (const p of points) {
    if (p.pinned) ctx.fillRect(p.x - 4, p.y - 4, 8, 8)
  }
}

// dragging
let held = null
let mouse = { x: 0, y: 0 }

canvas.addEventListener('pointerdown', e => {
  mouse = { x: e.clientX, y: e.clientY }
  let best = 30
  for (const p of points) {
    const d = Math.hypot(p.x - mouse.x, p.y - mouse.y)
    if (d < best) {
      best = d
      held = p
    }
  }
})
canvas.addEventListener('pointermove', e => {
  mouse = { x: e.clientX, y: e.clientY }
})
addEventListener('pointerup', () => { held = null })

function resize() {
  canvas.width = innerWidth
  canvas.height = innerHeight
}
addEventListener('resize', resize)
resize()

rope(innerWidth / 2, 80, 30, 12)

function frame() {
  if (held) {
    held.x = mouse.x
    held.y = mouse.y
  }
  update()
  draw()
  requestAnimationFrame(frame)
}
frame()
