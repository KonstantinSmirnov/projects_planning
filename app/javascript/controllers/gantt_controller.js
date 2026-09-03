import { Controller } from "@hotwired/stimulus"

const DAY_MS = 24 * 60 * 60 * 1000
const LABEL_WIDTH = 300
const HEADER_ROW_H = 28
const SPRINT_ROW_H = 20
const ROW_H = 30
const SNAP_THRESHOLD_DAYS = 3

// Painting order inside the chart. Row labels sit above the bars and the
// "today" marker because the label column is sticky and slides over them
// while scrolling; the date headers sit above everything for the same reason.
const Z = { bands: 0, bars: 1, today: 2, label: 10, header: 20, corner: 30 }

const SCALES = {
  quarter: { key: "quarter", label: "High level", primary: "quarter", secondary: "month", dayWidth: 4 },
  month: { key: "month", label: "Month / Week", primary: "month", secondary: "week", dayWidth: 10 },
  week: { key: "week", label: "Detailed", primary: "week", secondary: "day", dayWidth: 30 }
}

function parseDate(value) {
  return new Date(`${value}T00:00:00Z`)
}

function today() {
  const now = new Date()
  return new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()))
}

function addDays(date, days) {
  return new Date(date.getTime() + days * DAY_MS)
}

function daysBetween(a, b) {
  return Math.round((b.getTime() - a.getTime()) / DAY_MS)
}

function startOfMonth(date) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), 1))
}

function addMonths(date, n) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + n, 1))
}

function startOfQuarter(date) {
  const quarterMonth = Math.floor(date.getUTCMonth() / 3) * 3
  return new Date(Date.UTC(date.getUTCFullYear(), quarterMonth, 1))
}

function addQuarters(date, n) {
  return addMonths(date, n * 3)
}

function startOfWeek(date) {
  const dayOfWeek = (date.getUTCDay() + 6) % 7 // Monday = 0
  return addDays(date, -dayOfWeek)
}

function isWeekend(date) {
  const day = date.getUTCDay()
  return day === 0 || day === 6
}

const MONTH_NAMES = [ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" ]

function formatMonth(date) {
  return `${MONTH_NAMES[date.getUTCMonth()]} ${date.getUTCFullYear()}`
}

function formatShortDate(date) {
  return `${MONTH_NAMES[date.getUTCMonth()]} ${date.getUTCDate()}`
}

function isoDate(date) {
  return date.toISOString().slice(0, 10)
}

function el(tag, className, styles) {
  const node = document.createElement(tag)
  if (className) node.className = className
  if (styles) Object.assign(node.style, styles)
  return node
}

export default class extends Controller {
  static targets = [ "toolbar", "chart" ]
  static values = { projects: Array, sprints: Array, holidays: Array, teams: Array }

  // Runs once, before Stimulus establishes the initial values below — so
  // state the value-changed callbacks depend on already exists by the time
  // they can fire.
  initialize() {
    this.scale = "month"
    // Same reasoning as pendingCenterDate below: a full-page redirect after
    // adding a task/milestone can tear down and recreate this controller, so
    // isolation needs to survive that the same way the scroll position does.
    this.isolatedProjectId = this.readPersistedId("ganttIsolatedProjectId")
    this.teamFilterId = this.readPersistedId("ganttTeamFilterId")
    // Falls back to a persisted scroll position rather than always "today":
    // a full-page redirect after saving a milestone/task (data-turbo-frame
    // "_top") can lead Turbo's morph to replace this element outright rather
    // than patch it in place, tearing down and recreating the controller —
    // in that case `refresh()`'s in-memory carry-over never runs, so this is
    // the only thing standing between the user and getting snapped back to
    // today on every edit.
    this.pendingCenterDate = this.readPersistedCenterDate() || today()
    // Kept in memory too (not just sessionStorage) — see refresh()'s comment
    // for why a live DOM read of the scroll position can't be trusted there.
    this.lastKnownCenterDate = this.pendingCenterDate
    this.hasConnected = false
    this.releaseRowsExpanded = false
    this.holidaysVisible = this.readVisiblePref("ganttHolidaysVisible")
    this.releasesVisible = this.readVisiblePref("ganttReleasesVisible")
    this.stickToKeyDates = this.readVisiblePref("ganttStickToKeyDates")
    // Off by default, unlike the toggles above — an opt-in density increase
    // rather than something most of the chart's other features hinge on.
    this.showTitles = this.readVisiblePref("ganttShowTitles", false)
  }

  // Written continuously as the user scrolls (see connect()) and read back
  // here so the timeline survives a full reconnect, not just the in-memory
  // pendingCenterDate carry-over `refresh()` does for same-instance updates.
  // sessionStorage (not localStorage) is deliberate — this should reset with
  // a fresh tab/session, not follow the user around forever like a setting.
  readPersistedCenterDate() {
    try {
      const stored = window.sessionStorage.getItem("ganttCenterDate")
      return stored ? parseDate(stored) : null
    } catch {
      return null
    }
  }

  persistCenterDate(date) {
    try {
      window.sessionStorage.setItem("ganttCenterDate", isoDate(date))
    } catch {
      // Ignore — worst case the position doesn't survive a reload.
    }
  }

  // Same sessionStorage-survives-a-reconnect reasoning as the center date
  // above, for any single persisted id (project isolation, team filter).
  readPersistedId(key) {
    try {
      const stored = window.sessionStorage.getItem(key)
      return stored ? Number(stored) : null
    } catch {
      return null
    }
  }

  persistId(key, id) {
    try {
      if (id == null) {
        window.sessionStorage.removeItem(key)
      } else {
        window.sessionStorage.setItem(key, String(id))
      }
    } catch {
      // Ignore — worst case it doesn't survive a reload.
    }
  }

  // A per-browser display preference, not app data — kept in localStorage
  // rather than the database so it doesn't need a settings model for a
  // single-user app. Wrapped in try/catch since storage access can throw
  // (private browsing, disabled site data, etc.), in which case it just
  // falls back to `defaultValue` for that session. Shared by every toolbar
  // toggle — same behavior, different storage key and default.
  readVisiblePref(key, defaultValue = true) {
    try {
      const stored = window.localStorage.getItem(key)
      return stored === null ? defaultValue : stored === "true"
    } catch {
      return defaultValue
    }
  }

  writeVisiblePref(key, value) {
    try {
      window.localStorage.setItem(key, String(value))
    } catch {
      // Ignore — worst case the preference doesn't survive a reload.
    }
  }

  connect() {
    this.hasConnected = true
    this.renderToolbar()
    this.render()
    this.boundSchedulePersistCenterDate = () => this.schedulePersistCenterDate()
    this.chartTarget.addEventListener("scroll", this.boundSchedulePersistCenterDate)
    // The detail overlay's "Save" form lives outside this element entirely
    // (it's rendered into the layout's separate modal frame, not nested
    // inside the Gantt controller's own DOM subtree), so item_form_controller
    // reaches back here with a window event instead of a direct Stimulus
    // target/outlet relationship — see TASK-051.
    this.boundHandleItemSaved = (event) => this.handleItemSaved(event)
    window.addEventListener("gantt:item-saved", this.boundHandleItemSaved)
  }

  disconnect() {
    this.chartTarget.removeEventListener("scroll", this.boundSchedulePersistCenterDate)
    window.removeEventListener("gantt:item-saved", this.boundHandleItemSaved)
    clearTimeout(this.persistCenterDateTimer)
  }

  // `detail` carries the same shape a drag-persisted update does: enough to
  // build a synthetic "row" for the existing syncItemDates/refresh path,
  // rather than a second, parallel merge implementation.
  handleItemSaved({ detail: { kind, projectId, itemId, attrs } }) {
    this.syncItemDates({ sortableGroup: `${kind}-${projectId}`, sortableId: itemId }, attrs)
    this.refresh()
  }

  // Debounced rather than persisting on every scroll tick — this only needs
  // to capture roughly where the user ended up, not every intermediate
  // position while a scroll or drag is still in motion.
  schedulePersistCenterDate() {
    clearTimeout(this.persistCenterDateTimer)
    this.persistCenterDateTimer = setTimeout(() => {
      const date = this.centerDate()
      if (date) {
        this.lastKnownCenterDate = date
        this.persistCenterDate(date)
      }
    }, 150)
  }

  // Turbo's morph-based page refresh (see the `turbo-refresh-method` meta tag)
  // preserves this element across a redirect back to the same page — e.g.
  // after adding a task — rather than tearing it down and reconnecting it.
  // Without these, the projects/sprints values on the DOM element would
  // update but nothing would ever re-render the chart from them, leaving it
  // blank until a full manual reload. `hasConnected` (set by us, not a
  // Stimulus built-in — Controller has no such property) guards against
  // these firing during Stimulus's own initial setup, before `connect()` has
  // run once already, which would otherwise render twice on first load.
  projectsValueChanged() {
    if (this.hasConnected) this.refresh()
  }

  sprintsValueChanged() {
    if (this.hasConnected) this.refresh()
  }

  holidaysValueChanged() {
    if (this.hasConnected) this.refresh()
  }

  teamsValueChanged() {
    if (this.hasConnected) this.refresh()
  }

  // Every other caller of render() sets pendingCenterDate first so the
  // current view is preserved rather than snapping back to today (render()
  // always centers on pendingCenterDate, falling back to today if unset).
  // This is the shared path for re-renders triggered by a data change rather
  // than a direct user action on the toolbar, so it needs the same care.
  //
  // Deliberately prefers `lastKnownCenterDate` (tracked continuously — see
  // schedulePersistCenterDate and the end of render()) over a fresh
  // `centerDate()` read: this fires from a *ValueChanged callback, which on
  // Turbo's morph-based page refresh (data-turbo-frame "_top" redirects,
  // e.g. after adding a task) runs only after idiomorph has already
  // synchronously wiped chartTarget's children back to empty (the server
  // never renders anything inside it — we do, in JS, after the fact) to
  // match the freshly-fetched page. That wipe resets chartTarget.scrollLeft
  // to 0 *before* this callback ever runs, so a live centerDate() read at
  // this point doesn't return null (which the `|| today()` fallback could
  // catch) — it returns a real but wrong date computed from a scroll
  // position of 0, silently snapping the view to the start of the range.
  refresh() {
    this.pendingCenterDate = this.lastKnownCenterDate || this.centerDate() || today()
    this.renderToolbar()
    this.render()
  }

  // --- toolbar ------------------------------------------------------------

  renderToolbar() {
    this.toolbarTarget.innerHTML = ""

    if (this.isolatedProjectId != null) {
      const isolated = this.projectsValue.find((p) => p.id === this.isolatedProjectId)
      const badge = el("button", "text-xs pl-3 pr-2 py-1.5 mr-2 rounded-full border border-indigo-300 bg-indigo-50 text-indigo-700 hover:bg-indigo-100")
      badge.type = "button"
      badge.innerHTML = `Only <span class="font-semibold"></span> <span aria-hidden="true">&times;</span>`
      badge.querySelector("span").textContent = isolated ? isolated.name : "…"
      badge.title = "Show all projects again"
      badge.addEventListener("click", () => {
        this.isolatedProjectId = null
        this.persistId("ganttIsolatedProjectId", null)
        this.renderToolbar()
        this.render()
      })
      this.toolbarTarget.appendChild(badge)
    }

    if (this.teamsValue.length > 0) {
      // `select` gets `width: 100%` from the global base-layer form-control
      // styling (app/assets/tailwind/application.css) — harmless inside a
      // form, but it blows up this toolbar's flex layout unless overridden.
      const select = el("select", "w-auto shrink-0 text-xs px-2 py-1.5 mr-2 rounded border bg-white text-gray-600 border-gray-300")
      select.title = "Show only one team's tasks"

      const allOption = el("option", "")
      allOption.value = ""
      allOption.textContent = "All teams"
      select.appendChild(allOption)

      this.teamsValue.forEach((team) => {
        const option = el("option", "")
        option.value = String(team.id)
        option.textContent = team.name
        if (this.teamFilterId === team.id) option.selected = true
        select.appendChild(option)
      })

      select.addEventListener("change", () => {
        this.teamFilterId = select.value ? Number(select.value) : null
        this.persistId("ganttTeamFilterId", this.teamFilterId)
        this.pendingCenterDate = this.centerDate() || today()
        this.renderToolbar()
        this.render()
      })
      this.toolbarTarget.appendChild(select)
    }

    if (this.holidaysValue.length > 0) {
      this.toolbarTarget.appendChild(this.buildVisibilityToggleButton("Holidays", this.holidaysVisible, () => {
        this.holidaysVisible = !this.holidaysVisible
        this.writeVisiblePref("ganttHolidaysVisible", this.holidaysVisible)
        this.pendingCenterDate = this.centerDate() || today()
        this.renderToolbar()
        this.render()
      }))
    }

    if (this.sprintsValue.some((s) => s.release)) {
      this.toolbarTarget.appendChild(this.buildVisibilityToggleButton("Releases", this.releasesVisible, () => {
        this.releasesVisible = !this.releasesVisible
        this.writeVisiblePref("ganttReleasesVisible", this.releasesVisible)
        this.pendingCenterDate = this.centerDate() || today()
        this.renderToolbar()
        this.render()
      }))
    }

    // Always shown (unlike Holidays/Releases) — dragging is always possible,
    // regardless of whether any release sprint or holiday data exists. Only
    // affects future drags, not anything currently on screen, so this skips
    // the render() every other toggle does after itself.
    this.toolbarTarget.appendChild(this.buildVisibilityToggleButton("Stick to key dates", this.stickToKeyDates, () => {
      this.stickToKeyDates = !this.stickToKeyDates
      this.writeVisiblePref("ganttStickToKeyDates", this.stickToKeyDates)
      this.renderToolbar()
    }))

    // Always shown, same reasoning as "Stick to key dates" — titles can be
    // toggled regardless of what data currently exists.
    this.toolbarTarget.appendChild(this.buildVisibilityToggleButton("Titles", this.showTitles, () => {
      this.showTitles = !this.showTitles
      this.writeVisiblePref("ganttShowTitles", this.showTitles)
      this.pendingCenterDate = this.centerDate() || today()
      this.renderToolbar()
      this.render()
    }))

    const todayButton = el("button", "text-xs px-3 py-1.5 mr-2 rounded border bg-white text-gray-600 border-gray-300 hover:bg-gray-50")
    todayButton.type = "button"
    todayButton.textContent = "Today"
    todayButton.title = "Scroll the timeline back to today"
    todayButton.addEventListener("click", () => this.centerOn(today()))
    this.toolbarTarget.appendChild(todayButton)

    const group = el("div", "flex rounded border border-gray-300 overflow-hidden")
    Object.values(SCALES).forEach((scale) => {
      const button = el("button", this.toolbarButtonClass(scale.key))
      button.type = "button"
      button.textContent = scale.label
      button.dataset.scale = scale.key
      button.addEventListener("click", () => {
        if (this.scale === scale.key) return
        // Keep whatever the user is looking at in view across a zoom change.
        this.pendingCenterDate = this.centerDate() || today()
        this.scale = scale.key
        this.renderToolbar()
        this.render()
      })
      group.appendChild(button)
    })
    this.toolbarTarget.appendChild(group)
  }

  toolbarButtonClass(scaleKey) {
    const base = "text-xs px-3 py-1.5 border-r border-gray-300 last:border-r-0"
    return scaleKey === this.scale
      ? `${base} bg-indigo-600 text-white`
      : `${base} bg-white text-gray-600 hover:bg-gray-50`
  }

  // Shared by the "Holidays" and "Releases" toolbar toggles — same look and
  // behavior, just a different label/state/click handler.
  buildVisibilityToggleButton(label, isVisible, onToggle) {
    const button = el("button", isVisible
      ? "text-xs px-3 py-1.5 mr-2 rounded border bg-indigo-600 text-white border-indigo-600"
      : "text-xs px-3 py-1.5 mr-2 rounded border bg-white text-gray-600 border-gray-300 hover:bg-gray-50")
    button.type = "button"
    button.textContent = label
    button.title = isVisible ? `Hide ${label.toLowerCase()}` : `Show ${label.toLowerCase()}`
    button.addEventListener("click", onToggle)
    return button
  }

  isolateProject(projectId) {
    this.isolatedProjectId = this.isolatedProjectId === projectId ? null : projectId
    this.persistId("ganttIsolatedProjectId", this.isolatedProjectId)
    this.pendingCenterDate = this.centerDate() || today()
    this.renderToolbar()
    this.render()
  }

  toggleReleaseRows() {
    this.releaseRowsExpanded = !this.releaseRowsExpanded
    this.pendingCenterDate = this.centerDate() || today()
    this.render()
  }

  // --- scrolling ----------------------------------------------------------

  // Width of the actual timeline area — the sticky label column permanently
  // covers the left LABEL_WIDTH pixels of the scroll container.
  trackViewportWidth() {
    const width = this.chartTarget.clientWidth || this.chartTarget.offsetWidth || window.innerWidth || 0
    return Math.max(0, width - LABEL_WIDTH)
  }

  // The date currently in the middle of the visible timeline, or null if the
  // chart has not been laid out yet.
  centerDate() {
    if (!this.rangeStart || !this.trackViewportWidth()) return null
    const centerPx = this.chartTarget.scrollLeft + LABEL_WIDTH + this.trackViewportWidth() / 2 - LABEL_WIDTH
    return addDays(this.rangeStart, Math.round(centerPx / SCALES[this.scale].dayWidth))
  }

  centerOn(date) {
    if (!this.rangeStart) return
    const scale = SCALES[this.scale]
    const apply = () => {
      const offsetPx = daysBetween(this.rangeStart, date) * scale.dayWidth
      this.chartTarget.scrollLeft = Math.max(0, offsetPx - this.trackViewportWidth() / 2)
    }
    // The chart has no measurable width until after the first layout pass, so
    // centring runs on the next frame rather than straight out of connect().
    apply()
    requestAnimationFrame(apply)
  }

  // --- rendering ----------------------------------------------------------

  render() {
    this.chartTarget.innerHTML = ""
    const visibleProjects = this.isolatedProjectId == null
      ? this.projectsValue
      : this.projectsValue.filter((p) => p.id === this.isolatedProjectId)
    // With a team filter active, projectRows() already drops milestones and
    // every non-matching task — a project contributing nothing but its own
    // row (no matching work) disappears entirely, since the point of the
    // filter is seeing only what that team has to do.
    const rows = visibleProjects.flatMap((project) => {
      const projectRows = this.projectRows(project)
      if (this.teamFilterId != null && projectRows.length === 1) return []
      return projectRows
    })
    const dated = rows.filter((row) => row.start && row.end)
    const sprintTimes = this.sprintsValue.flatMap((s) => [ parseDate(s.start_date).getTime(), parseDate(s.end_date).getTime() ])

    if (rows.length === 0 && sprintTimes.length === 0) {
      this.chartTarget.appendChild(this.emptyState())
      return
    }

    // The visible range picks whichever candidate is more generous on each
    // side: the earliest/latest dated milestone/task, or the earliest/latest
    // configured sprint (sprintTimes already covers every sprint, so its own
    // min/max is exactly the first sprint's start and the last sprint's end)
    // — each padded a month further out for breathing room.
    const scale = SCALES[this.scale]
    const itemTimes = dated.flatMap((i) => [ i.start.getTime(), i.end.getTime() ])
    const startCandidates = []
    const endCandidates = []
    if (itemTimes.length) {
      startCandidates.push(Math.min(...itemTimes))
      endCandidates.push(Math.max(...itemTimes))
    }
    if (sprintTimes.length) {
      startCandidates.push(Math.min(...sprintTimes))
      endCandidates.push(Math.max(...sprintTimes))
    }
    const rawStart = addMonths(new Date(Math.min(...startCandidates)), -1)
    const rawEnd = addMonths(new Date(Math.max(...endCandidates)), 1)

    const { rangeStart, rangeEnd } = this.snapRange(rawStart, rawEnd, scale)
    this.rangeStart = rangeStart
    this.rangeEnd = rangeEnd
    const totalDays = daysBetween(rangeStart, rangeEnd)
    const totalWidth = totalDays * scale.dayWidth

    // Sprints marked "release" get three fixed, computed rows (never one per
    // sprint — every release sprint just adds another marker within these
    // same three), pinned above the projects. Collapsed by default into a
    // single group header row so they don't crowd the sidebar; the header's
    // own track still overlays all three color-coded marker types so nothing
    // is hidden by collapsing, just the per-type row labels. Hidden entirely
    // by the "Releases" toolbar toggle.
    const releaseSprints = this.releasesVisible ? this.sprintsValue.filter((s) => s.release) : []
    const releaseRowDefs = releaseSprints.length === 0 ? [] : [
      { label: "Code freeze", dateKey: "code_freeze_date", colorClass: "bg-blue-500" },
      { label: "Submit to store", dateKey: "submit_to_store_date", colorClass: "bg-violet-500" },
      { label: "Publish", dateKey: "publish_date", colorClass: "bg-green-500" }
    ].map((def) => ({
      label: def.label,
      colorClass: def.colorClass,
      markers: releaseSprints.map((s) => ({ date: parseDate(s[def.dateKey]), sprintNumber: s.number }))
    }))
    const releaseRowCount = releaseRowDefs.length === 0 ? 0 : (this.releaseRowsExpanded ? releaseRowDefs.length + 1 : 1)

    // One shared row for every region's holidays that fall within the
    // visible range — hidden entirely by the "Holidays" toolbar toggle.
    const visibleHolidays = this.holidaysVisible
      ? this.holidaysValue.filter((h) => {
        const date = parseDate(h.date)
        return date >= rangeStart && date <= rangeEnd
      })
      : []
    const holidayRowCount = visibleHolidays.length > 0 ? 1 : 0

    const bodyHeight = (rows.length + releaseRowCount + holidayRowCount) * ROW_H

    const wrapper = el("div", "relative", { width: `${LABEL_WIDTH + totalWidth}px` })

    wrapper.appendChild(this.buildHeaderRow(rangeStart, scale, scale.primary, totalWidth, 0, rows.length))
    wrapper.appendChild(this.buildHeaderRow(rangeStart, scale, scale.secondary, totalWidth, HEADER_ROW_H))
    wrapper.appendChild(this.buildSprintRow(rangeStart, rangeEnd, scale, totalWidth))

    const body = el("div", "relative")
    body.appendChild(this.buildOverlay(rangeStart, rangeEnd, scale, totalWidth, bodyHeight))

    // Holidays/releases stay pinned under the sprint row while scrolling
    // down, the same way the header rows and sprint row already do — each
    // sticky row's `top` stacks on however many sticky rows come before it.
    let stickyTop = HEADER_ROW_H * 2 + SPRINT_ROW_H
    if (holidayRowCount > 0) {
      body.appendChild(this.buildHolidayRow(visibleHolidays, rangeStart, scale, totalWidth, stickyTop))
      stickyTop += ROW_H
    }
    if (releaseRowDefs.length > 0) {
      body.appendChild(this.buildReleaseGroupHeader(releaseRowDefs, rangeStart, scale, totalWidth, stickyTop))
      stickyTop += ROW_H
      if (this.releaseRowsExpanded) {
        releaseRowDefs.forEach((def) => {
          body.appendChild(this.buildReleaseRow(def.label, def.colorClass, def.markers, rangeStart, scale, totalWidth, stickyTop))
          stickyTop += ROW_H
        })
      }
    }
    rows.forEach((row) => body.appendChild(this.buildRow(row, rangeStart, scale, totalWidth)))

    // Spans the rows only — never the sticky header strip above them — and
    // sits below the sticky label column so it can't paint over the names.
    const todayDate = today()
    if (todayDate >= rangeStart && todayDate <= rangeEnd && bodyHeight > 0) {
      const nowLine = el("div", "absolute bg-red-500", {
        left: `${LABEL_WIDTH + daysBetween(rangeStart, todayDate) * scale.dayWidth}px`,
        top: "0", width: "2px", height: `${bodyHeight}px`, zIndex: Z.today
      })
      nowLine.title = `Today — ${isoDate(todayDate)}`
      body.appendChild(nowLine)
    }

    wrapper.appendChild(body)
    this.chartTarget.appendChild(wrapper)

    this.centerOn(this.pendingCenterDate || todayDate)
    this.lastKnownCenterDate = this.pendingCenterDate || todayDate
    this.pendingCenterDate = null
  }

  emptyState() {
    const box = el("div", "p-10 text-center")
    const title = el("p", "text-sm font-medium text-gray-600")
    title.textContent = "Nothing on the timeline yet"
    const hint = el("p", "text-sm text-gray-400 mt-1")
    hint.textContent = "Add a project, then give it a milestone or a task to see it here."
    box.appendChild(title)
    box.appendChild(hint)
    return box
  }

  projectRows(project) {
    const rows = []
    const projectUrl = `/projects/${project.id}`
    const start = project.start_date ? parseDate(project.start_date) : null
    const end = project.end_date ? parseDate(project.end_date) : null

    rows.push({
      type: "project",
      label: project.name,
      dateLabel: start && end ? `${formatShortDate(start)}–${formatShortDate(end)}` : "",
      start,
      end,
      href: projectUrl,
      addHref: `${projectUrl}/new_item`,
      projectId: project.id,
      sortableId: project.id,
      sortableGroup: "projects",
      sortableUrl: "/projects/reorder"
    })

    // A team filter narrows this down to just that team's tasks — milestones
    // aren't owned by any team, so they're left out entirely while a filter
    // is active rather than shown for every team regardless of relevance.
    if (this.teamFilterId == null) {
      project.milestones.forEach((milestone) => {
        const date = parseDate(milestone.date)
        rows.push({
          type: "milestone",
          label: milestone.name,
          dateLabel: formatShortDate(date),
          start: date,
          end: date,
          href: `${projectUrl}/milestones/${milestone.id}`,
          verified: milestone.verified,
          sortableId: milestone.id,
          sortableGroup: `milestones-${project.id}`,
          sortableUrl: `${projectUrl}/milestones/reorder`
        })
      })
    }

    project.tasks.forEach((task) => {
      if (this.teamFilterId != null && task.team_id !== this.teamFilterId) return

      const start = parseDate(task.start_date)
      const end = parseDate(task.end_date)
      rows.push({
        type: "task",
        label: task.name,
        dateLabel: `${formatShortDate(start)}–${formatShortDate(end)}`,
        start,
        end,
        href: `${projectUrl}/tasks/${task.id}`,
        teamColor: task.team_color,
        teamName: task.team_name,
        verified: task.verified,
        sortableId: task.id,
        sortableGroup: `tasks-${project.id}`,
        sortableUrl: `${projectUrl}/tasks/reorder`
      })
    })

    return rows
  }

  snapRange(start, end, scale) {
    if (scale.primary === "quarter") {
      return { rangeStart: startOfQuarter(start), rangeEnd: addQuarters(startOfQuarter(end), 1) }
    }
    if (scale.primary === "month") {
      return { rangeStart: startOfMonth(start), rangeEnd: addMonths(startOfMonth(end), 1) }
    }
    return { rangeStart: startOfWeek(start), rangeEnd: addDays(startOfWeek(end), 7) }
  }

  buildHeaderRow(rangeStart, scale, unit, totalWidth, top, rowCount) {
    const row = el("div", "flex", { position: "sticky", top: `${top}px`, zIndex: Z.header })

    const corner = el("div", "sticky left-0 bg-gray-50 border-r border-b border-gray-200 shrink-0 flex items-center px-2", {
      width: `${LABEL_WIDTH}px`, height: `${HEADER_ROW_H}px`, zIndex: Z.corner
    })
    if (rowCount !== undefined) {
      const heading = el("span", "text-xs font-semibold uppercase tracking-wide text-gray-500")
      heading.textContent = "Projects"
      corner.appendChild(heading)
    }
    row.appendChild(corner)

    const track = el("div", "flex bg-gray-50 border-b border-gray-200", { width: `${totalWidth}px`, height: `${HEADER_ROW_H}px` })

    let cursor = rangeStart
    const rangeEndDate = addDays(rangeStart, totalWidth / scale.dayWidth)
    const todayDate = today()

    while (cursor < rangeEndDate) {
      let next
      let label
      if (unit === "quarter") {
        next = addQuarters(cursor, 1)
        label = `Q${Math.floor(cursor.getUTCMonth() / 3) + 1} ${cursor.getUTCFullYear()}`
      } else if (unit === "month") {
        next = addMonths(cursor, 1)
        label = formatMonth(cursor)
      } else if (unit === "week") {
        next = addDays(cursor, 7)
        label = formatShortDate(cursor)
      } else {
        next = addDays(cursor, 1)
        label = String(cursor.getUTCDate())
      }

      const width = daysBetween(cursor, next) * scale.dayWidth
      const isToday = unit === "day" && cursor.getTime() === todayDate.getTime()
      const weekendTint = unit === "day" && isWeekend(cursor) ? " bg-gray-100 text-gray-400" : ""
      const todayTint = isToday ? " bg-red-50 text-red-600 font-semibold" : ""
      const cell = el("div",
        `shrink-0 border-r border-gray-200 text-xs text-gray-600 flex items-center px-2 truncate${weekendTint}${todayTint}`,
        { width: `${width}px` })
      cell.textContent = label
      track.appendChild(cell)
      cursor = next
    }

    row.appendChild(track)
    return row
  }

  buildSprintRow(rangeStart, rangeEnd, scale, totalWidth) {
    const row = el("div", "flex", { position: "sticky", top: `${HEADER_ROW_H * 2}px`, zIndex: Z.header })

    const corner = el("div", "sticky left-0 bg-indigo-50 border-r border-b border-gray-200 shrink-0 text-xs text-indigo-400 flex items-center px-2", {
      width: `${LABEL_WIDTH}px`, height: `${SPRINT_ROW_H}px`, zIndex: Z.corner
    })
    corner.textContent = "Sprints"
    row.appendChild(corner)

    const track = el("div", "relative bg-indigo-50 border-b border-gray-200", { width: `${totalWidth}px`, height: `${SPRINT_ROW_H}px` })
    const todayDate = today()

    this.sprintsCovering(rangeStart, rangeEnd).forEach((sprint) => {
      const left = Math.max(0, daysBetween(rangeStart, sprint.start)) * scale.dayWidth
      const right = Math.min(totalWidth / scale.dayWidth, daysBetween(rangeStart, sprint.end) + 1) * scale.dayWidth
      const width = right - left
      if (width <= 0) return

      const isCurrent = todayDate >= sprint.start && todayDate <= sprint.end
      const colors = isCurrent
        ? "border-emerald-300 bg-emerald-100 text-emerald-800 font-semibold"
        : "border-indigo-200 text-indigo-700 hover:bg-indigo-100"
      const cell = el("a", `absolute border-r text-[11px] flex items-center justify-center overflow-hidden cursor-pointer ${colors}`, {
        left: `${left}px`, width: `${width}px`, height: `${SPRINT_ROW_H}px`
      })
      cell.href = `/sprints/${sprint.number}`
      cell.dataset.turboFrame = "modal_body"
      cell.title = `Sprint ${sprint.number}: ${isoDate(sprint.start)} → ${isoDate(sprint.end)}${isCurrent ? " (current)" : ""} — click for details`
      if (width >= 28) cell.textContent = `S${sprint.number}`
      track.appendChild(cell)
    })

    row.appendChild(track)
    return row
  }

  buildOverlay(rangeStart, rangeEnd, scale, totalWidth, bodyHeight) {
    const overlay = el("div", "absolute", { left: `${LABEL_WIDTH}px`, top: "0", width: `${totalWidth}px`, height: `${bodyHeight}px`, zIndex: Z.bands })
    const todayDate = today()

    // Weekend shading is only legible once a day is wide enough to see.
    if (scale.dayWidth >= 20) {
      const totalDays = totalWidth / scale.dayWidth
      for (let i = 0; i < totalDays; i++) {
        const day = addDays(rangeStart, i)
        if (!isWeekend(day)) continue
        overlay.appendChild(el("div", "absolute top-0 bg-gray-100/70", {
          left: `${i * scale.dayWidth}px`, width: `${scale.dayWidth}px`, height: `${bodyHeight}px`
        }))
      }
    }

    this.sprintsCovering(rangeStart, rangeEnd).forEach((sprint, index) => {
      const left = Math.max(0, daysBetween(rangeStart, sprint.start)) * scale.dayWidth
      const right = Math.min(totalWidth / scale.dayWidth, daysBetween(rangeStart, sprint.end) + 1) * scale.dayWidth
      const width = right - left
      if (width <= 0) return

      const isCurrent = todayDate >= sprint.start && todayDate <= sprint.end
      const shade = isCurrent ? "bg-emerald-50" : index % 2 === 0 ? "bg-indigo-50/40" : "bg-transparent"
      overlay.appendChild(el("div", `absolute top-0 ${shade}`, {
        left: `${left}px`, width: `${width}px`, height: `${bodyHeight}px`
      }))
    })

    return overlay
  }

  buildRow(row, rangeStart, scale, totalWidth) {
    const rowEl = el("div", `flex relative group ${row.type === "project" ? "bg-gray-50/60" : ""}`, { height: `${ROW_H}px` })
    rowEl.dataset.sortableId = row.sortableId
    rowEl.dataset.sortableGroup = row.sortableGroup
    rowEl.dataset.sortableUrl = row.sortableUrl

    // A task currently between its own start and end date is "in progress" —
    // highlighted in the sidebar the same way the sprints overlay highlights
    // the current sprint.
    const isInProgressTask = row.type === "task" && row.start && row.end && today() >= row.start && today() <= row.end
    const labelClasses = row.type === "project"
      ? "sticky left-0 bg-gray-50 border-r border-b border-gray-200 shrink-0 text-xs font-semibold text-gray-800 flex items-center gap-1 pl-1 pr-2 group-hover:bg-gray-100"
      : `sticky left-0 ${isInProgressTask ? "bg-emerald-50" : "bg-white"} border-r border-b border-gray-100 shrink-0 text-xs text-gray-600 flex items-center gap-1 pl-1 pr-2 group-hover:bg-gray-50`
    const label = el("div", labelClasses, { width: `${LABEL_WIDTH}px`, height: `${ROW_H}px`, zIndex: Z.label })

    // A dedicated handle, so dragging a row never fights with the browser's
    // own "drag this link" behaviour on the name.
    const handle = el("span", "shrink-0 w-4 text-center text-gray-300 cursor-grab select-none opacity-0 group-hover:opacity-100")
    handle.textContent = "⠿"
    handle.title = "Drag to reorder"
    handle.draggable = true
    label.appendChild(handle)

    // Milestones keep their amber diamond; tasks show a team-initial badge
    // instead of a bullet (below) — the in-progress state is signaled purely
    // by the row's background tint above, no separate icon for it.
    if (row.type === "milestone") {
      const bullet = el("span", "shrink-0 text-amber-500")
      bullet.textContent = "◆"
      label.appendChild(bullet)
    }

    if (row.type === "task" && row.teamColor) {
      const badge = el("span", "shrink-0 w-4 h-4 rounded-full flex items-center justify-center text-[9px] font-bold text-white",
        { backgroundColor: row.teamColor })
      badge.textContent = (row.teamName || "?").charAt(0).toUpperCase()
      badge.title = row.teamName || ""
      label.appendChild(badge)
    }

    const link = el("a", "truncate flex-1 min-w-0 hover:underline")
    link.href = row.href
    link.draggable = false
    link.dataset.turboFrame = "modal_body"
    link.title = row.label
    link.textContent = row.label
    label.appendChild(link)

    if (row.verified && row.type !== "project") {
      const check = el("span", "shrink-0 text-emerald-600 text-xs")
      check.textContent = "✓"
      check.title = "Verified"
      label.appendChild(check)
    }

    if (row.dateLabel) {
      const dateEl = el("span", "shrink-0 text-[11px] text-gray-400 tabular-nums")
      dateEl.textContent = row.dateLabel
      label.appendChild(dateEl)
    }

    if (row.type === "project") {
      const isIsolated = this.isolatedProjectId === row.projectId
      const isolateBtn = el("button", `shrink-0 px-1 ${isIsolated ? "text-indigo-600" : "text-gray-400 hover:text-indigo-600 opacity-0 group-hover:opacity-100"}`)
      isolateBtn.type = "button"
      isolateBtn.title = isIsolated ? "Show all projects again" : "Show only this project"
      isolateBtn.textContent = "◎"
      isolateBtn.addEventListener("click", (event) => {
        event.preventDefault()
        this.isolateProject(row.projectId)
      })
      label.appendChild(isolateBtn)

      const addLink = el("a", "shrink-0 px-1 text-indigo-500 hover:text-indigo-700 font-semibold")
      addLink.href = row.addHref
      addLink.draggable = false
      addLink.dataset.turboFrame = "modal_body"
      addLink.title = "Add a milestone or task"
      addLink.textContent = "+"
      label.appendChild(addLink)
    }

    rowEl.appendChild(label)
    this.wireRowDrag(rowEl, handle)

    const track = el("div", `relative border-b ${row.type === "project" ? "border-gray-200" : "border-gray-100"}`,
      { width: `${totalWidth}px`, height: `${ROW_H}px`, zIndex: Z.bars })

    if (row.start && row.end) {
      const left = daysBetween(rangeStart, row.start) * scale.dayWidth
      const durationDays = Math.max(1, daysBetween(row.start, row.end) + 1)
      const width = durationDays * scale.dayWidth

      if (row.type === "milestone") {
        const draggableMilestone = !row.verified
        const marker = el("div", "absolute bg-amber-500 rotate-45 rounded-[2px] shadow-sm cursor-pointer", {
          left: `${left + width / 2 - 6}px`, top: `${ROW_H / 2 - 6}px`, width: "12px", height: "12px"
        })
        marker.title = draggableMilestone
          ? `${row.label} — ${isoDate(row.start)} (click to open, drag to move)`
          : `${row.label} — ${isoDate(row.start)} (verified — click to open; un-verify to move)`
        marker.draggable = false
        if (draggableMilestone) this.wireMilestoneDrag(marker, row, scale)
        else marker.addEventListener("click", () => this.navigateToOverlay(row.href))
        track.appendChild(marker)
        this.appendItemTitle(track, row, left + width / 2 - 6, 12)
      } else {
        const draggable = row.type === "task" && !row.verified
        // A task assigned to a team is colored with that team's arbitrary,
        // user-picked color — set as an inline style rather than a Tailwind
        // class, since Tailwind's build-time scanner can never know about a
        // color chosen at runtime. Falls back to the default blue class.
        const useTeamColor = row.type === "task" && row.teamColor
        const colorClass = row.type === "project" ? "bg-slate-400" : (useTeamColor ? "" : "bg-blue-500")
        const clickableOnly = row.type === "task" && row.verified
        const bar = el("div", `absolute rounded ${colorClass} ${draggable || clickableOnly ? "cursor-pointer hover:brightness-110" : ""}`, {
          left: `${left}px`, top: row.type === "project" ? "10px" : "6px", width: `${Math.max(width, 3)}px`,
          height: row.type === "project" ? "10px" : "18px",
          ...(useTeamColor ? { backgroundColor: row.teamColor } : {})
        })
        if (draggable) {
          bar.title = `${row.label} — ${isoDate(row.start)} → ${isoDate(row.end)} (click to open, drag to move, edges to resize)`
        } else if (clickableOnly) {
          bar.title = `${row.label} — ${isoDate(row.start)} → ${isoDate(row.end)} (verified — click to open; un-verify to move)`
        } else {
          bar.title = `${row.label} — ${isoDate(row.start)} → ${isoDate(row.end)}`
        }
        bar.draggable = false

        if (draggable) {
          this.wireBarMove(bar, row, scale)

          const leftHandle = el("div", "absolute inset-y-0 left-0 w-1.5 cursor-ew-resize hover:bg-white/40 rounded-l")
          const rightHandle = el("div", "absolute inset-y-0 right-0 w-1.5 cursor-ew-resize hover:bg-white/40 rounded-r")
          bar.appendChild(leftHandle)
          bar.appendChild(rightHandle)
          this.wireBarResize(leftHandle, bar, row, scale, "start")
          this.wireBarResize(rightHandle, bar, row, scale, "end")
        } else if (clickableOnly) {
          bar.addEventListener("click", () => this.navigateToOverlay(row.href))
        }

        track.appendChild(bar)
        if (row.type === "task") this.appendItemTitle(track, row, left, Math.max(width, 3))
      }
    }

    rowEl.appendChild(track)
    return rowEl
  }

  // TASK-054: an opt-in label showing a milestone/task's own name right on
  // the timeline, next to its bar/marker — so it doesn't have to be read off
  // the sidebar separately. `pointer-events-none` keeps it from stealing
  // clicks/drags meant for the bar/marker it's labeling; deliberately not
  // width-constrained (it can run past the bar into open space to its
  // right), matching how most Gantt tools show inline bar labels.
  appendItemTitle(track, row, left, width) {
    if (!this.showTitles) return
    const titleEl = el("div", "absolute text-[11px] text-gray-700 whitespace-nowrap pointer-events-none", {
      left: `${left + width + 6}px`, top: "0", height: `${ROW_H}px`, lineHeight: `${ROW_H}px`
    })
    titleEl.textContent = row.label
    track.appendChild(titleEl)
  }

  // Read-only row for every visible public holiday across all regions —
  // color-coded per region (see PublicHoliday::REGION_COLORS), all sharing
  // one row rather than one per country to keep the sidebar compact.
  buildHolidayRow(holidays, rangeStart, scale, totalWidth, stickyTop) {
    const rowEl = el("div", "flex relative bg-gray-50/60", { height: `${ROW_H}px`, position: "sticky", top: `${stickyTop}px`, zIndex: Z.header })

    const labelEl = el("div", "sticky left-0 bg-gray-50 border-r border-b border-gray-200 shrink-0 text-xs font-medium text-gray-700 flex items-center pl-2 pr-2 truncate", {
      width: `${LABEL_WIDTH}px`, height: `${ROW_H}px`, zIndex: Z.corner
    })
    labelEl.textContent = "Public holidays"
    rowEl.appendChild(labelEl)

    const track = el("div", "relative border-b border-gray-100", { width: `${totalWidth}px`, height: `${ROW_H}px`, zIndex: Z.bars })
    const items = holidays.map((h) => ({ ...h, colorClass: h.color_class }))
    this.appendDayBands(track, items, rangeStart, scale, {
      title: (h, dateKey) => `${h.region_label} — ${h.name} — ${dateKey} (click for details)`,
      // The details overlay looks up every holiday on this date
      // server-side, not just the one region this particular band is for.
      onClick: (h, dateKey) => this.navigateToOverlay(`/public_holidays?date=${dateKey}`)
    })
    rowEl.appendChild(track)

    return rowEl
  }

  // Collapsed-by-default summary row for the release-sprint dates: one
  // clickable label ("Release ▸ N dates") whose track still overlays every
  // color-coded marker from all three date types, so nothing disappears when
  // the per-type rows are collapsed — only their separate labels do.
  buildReleaseGroupHeader(releaseRowDefs, rangeStart, scale, totalWidth, stickyTop) {
    const rowEl = el("div", "flex relative bg-gray-50", { height: `${ROW_H}px`, position: "sticky", top: `${stickyTop}px`, zIndex: Z.header })

    const labelEl = el("button", "sticky left-0 bg-gray-50 border-r border-b border-gray-200 shrink-0 text-xs font-medium text-gray-700 flex items-center gap-1 pl-2 pr-2 truncate hover:bg-gray-100 cursor-pointer", {
      width: `${LABEL_WIDTH}px`, height: `${ROW_H}px`, zIndex: Z.corner
    })
    labelEl.type = "button"
    const totalMarkers = releaseRowDefs.reduce((sum, def) => sum + def.markers.length, 0)
    labelEl.innerHTML = `<span aria-hidden="true">${this.releaseRowsExpanded ? "▾" : "▸"}</span> Release <span class="text-gray-400">(${totalMarkers})</span>`
    labelEl.title = this.releaseRowsExpanded ? "Collapse release dates" : "Expand to see code freeze / submit to store / publish separately"
    labelEl.addEventListener("click", () => this.toggleReleaseRows())
    rowEl.appendChild(labelEl)

    const track = el("div", "relative border-b border-gray-100", { width: `${totalWidth}px`, height: `${ROW_H}px`, zIndex: Z.bars })
    const flatMarkers = releaseRowDefs.flatMap((def) =>
      def.markers.map((m) => ({ ...m, label: def.label, colorClass: def.colorClass })))
    this.appendDayBands(track, flatMarkers, rangeStart, scale, {
      title: (m, dateKey) => `${m.label} — Sprint ${m.sprintNumber} — ${dateKey}`
    })
    rowEl.appendChild(track)

    return rowEl
  }

  // Read-only, computed rows for release-sprint dates — not tied to any
  // project, so no drag/reorder/click-to-edit; one marker per release sprint.
  // Only rendered when the group header above is expanded.
  buildReleaseRow(label, colorClass, markers, rangeStart, scale, totalWidth, stickyTop) {
    const rowEl = el("div", "flex relative bg-gray-50/60", { height: `${ROW_H}px`, position: "sticky", top: `${stickyTop}px`, zIndex: Z.header })

    const labelEl = el("div", "sticky left-0 bg-gray-50 border-r border-b border-gray-200 shrink-0 text-xs text-gray-600 flex items-center pl-6 pr-2 truncate", {
      width: `${LABEL_WIDTH}px`, height: `${ROW_H}px`, zIndex: Z.corner
    })
    labelEl.textContent = label
    rowEl.appendChild(labelEl)

    const track = el("div", "relative border-b border-gray-100", { width: `${totalWidth}px`, height: `${ROW_H}px`, zIndex: Z.bars })
    this.appendDayBands(track, markers.map((m) => ({ ...m, colorClass })), rangeStart, scale, {
      title: (m, dateKey) => `${label} — Sprint ${m.sprintNumber} — ${dateKey}`
    })
    rowEl.appendChild(track)

    return rowEl
  }

  // Shared by the holiday row and both release rows: renders each item as a
  // band spanning the full width of the day it falls on (rather than a small
  // marker centered on it), grouping same-date items into equal horizontal
  // stripes so nothing gets fully hidden behind another item at the same spot.
  // `date` on each item may be a Date or an ISO string — normalized here so
  // callers don't have to agree on one representation.
  appendDayBands(track, items, rangeStart, scale, { title, onClick } = {}) {
    const byDate = new Map()
    items.forEach((item) => {
      const date = item.date instanceof Date ? item.date : parseDate(item.date)
      const key = isoDate(date)
      if (!byDate.has(key)) byDate.set(key, [])
      byDate.get(key).push({ ...item, date })
    })

    byDate.forEach((dayItems, dateKey) => {
      const left = daysBetween(rangeStart, dayItems[0].date) * scale.dayWidth
      const stripeHeight = ROW_H / dayItems.length
      dayItems.forEach((item, index) => {
        const band = el("div", `absolute ${item.colorClass} opacity-80 hover:opacity-100 ${onClick ? "cursor-pointer" : ""}`, {
          left: `${left}px`, top: `${index * stripeHeight}px`, width: `${scale.dayWidth}px`, height: `${stripeHeight}px`
        })
        band.title = title(item, dateKey)
        if (onClick) band.addEventListener("click", () => onClick(item, dateKey))
        track.appendChild(band)
      })
    })
  }

  // Rows are grouped by `sortableGroup` (all projects together; a given
  // project's milestones together; its tasks together). Dropping only
  // reorders within the same group and persists via that group's own url.
  wireRowDrag(rowEl, handle) {
    handle.addEventListener("dragstart", (event) => {
      event.dataTransfer.effectAllowed = "move"
      event.dataTransfer.setData("text/plain", JSON.stringify({
        id: rowEl.dataset.sortableId, group: rowEl.dataset.sortableGroup
      }))
      rowEl.classList.add("opacity-40")
    })

    handle.addEventListener("dragend", () => {
      rowEl.classList.remove("opacity-40")
      this.clearDropHint()
    })

    rowEl.addEventListener("dragover", (event) => {
      event.preventDefault()
      this.clearDropHint()
      const rect = rowEl.getBoundingClientRect()
      const before = event.clientY - rect.top < rect.height / 2
      rowEl.classList.add(before ? "border-t-2" : "border-b-2", "border-indigo-500")
      this.dropHintEl = rowEl
    })

    rowEl.addEventListener("dragleave", () => this.clearDropHint())

    rowEl.addEventListener("drop", (event) => {
      event.preventDefault()
      this.clearDropHint()

      let dragged
      try {
        dragged = JSON.parse(event.dataTransfer.getData("text/plain"))
      } catch { return }
      if (!dragged || dragged.group !== rowEl.dataset.sortableGroup) return
      if (String(dragged.id) === rowEl.dataset.sortableId) return

      const groupSelector = `[data-sortable-group="${rowEl.dataset.sortableGroup}"]`
      const groupRows = Array.from(this.chartTarget.querySelectorAll(groupSelector))
      const draggedEl = groupRows.find((item) => item.dataset.sortableId === String(dragged.id))
      if (!draggedEl) return

      const rect = rowEl.getBoundingClientRect()
      const placeBefore = event.clientY - rect.top < rect.height / 2
      rowEl.parentElement.insertBefore(draggedEl, placeBefore ? rowEl : rowEl.nextSibling)

      const ids = Array.from(this.chartTarget.querySelectorAll(groupSelector)).map((item) => item.dataset.sortableId)
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

      fetch(rowEl.dataset.sortableUrl, {
        method: "PATCH",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken, Accept: "application/json" },
        body: JSON.stringify({ ids })
      })
        .then((response) => { if (response.ok) this.syncOrder(rowEl.dataset.sortableGroup, ids) })
        .catch((error) => console.error("Failed to save new order", error))
    })
  }

  clearDropHint() {
    if (!this.dropHintEl) return
    this.dropHintEl.classList.remove("border-t-2", "border-b-2", "border-indigo-500")
    this.dropHintEl = null
  }

  // Keeps the in-memory payload in step with the saved order, so a later
  // re-render (scale switch, isolate) doesn't snap rows back.
  syncOrder(group, ids) {
    const byId = (list) => ids.map((id) => list.find((item) => String(item.id) === String(id))).filter(Boolean)

    if (group === "projects") {
      this.projectsValue = byId(this.projectsValue)
      return
    }

    const [ kind, projectId ] = group.split("-")
    const projects = this.projectsValue.map((project) => {
      if (String(project.id) !== projectId) return project
      return { ...project, [kind]: byId(project[kind]) }
    })
    this.projectsValue = projects
  }

  // --- moving / resizing bars and markers on the timeline -----------------

  // "Stick to key dates" (TASK-050): every sprint boundary, every derived
  // release date (code freeze / submit to store / publish) on a release
  // sprint, and every milestone in the *same project* as whatever's being
  // dragged — excluding the dragged item itself, if it's the milestone.
  // Recomputed once per drag gesture (not per mousemove) since none of this
  // changes mid-drag.
  keyDatesFor(row) {
    if (!this.stickToKeyDates) return []

    const dates = []
    this.sprintsValue.forEach((sprint) => {
      dates.push(parseDate(sprint.start_date), parseDate(sprint.end_date))
      if (sprint.release) {
        dates.push(parseDate(sprint.code_freeze_date), parseDate(sprint.submit_to_store_date), parseDate(sprint.publish_date))
      }
    })

    const [ , projectId ] = row.sortableGroup.split("-")
    const project = this.projectsValue.find((p) => String(p.id) === projectId)
    if (project) {
      project.milestones.forEach((milestone) => {
        if (row.type === "milestone" && String(milestone.id) === String(row.sortableId)) return
        dates.push(parseDate(milestone.date))
      })
    }

    return dates
  }

  // The nearest key date within SNAP_THRESHOLD_DAYS of `date`, or `date`
  // itself unchanged if none are close enough.
  snapDate(date, keyDates) {
    let closest = null
    let closestDistance = Infinity

    keyDates.forEach((keyDate) => {
      const distance = Math.abs(daysBetween(date, keyDate))
      if (distance <= SNAP_THRESHOLD_DAYS && distance < closestDistance) {
        closest = keyDate
        closestDistance = distance
      }
    })

    return closest || date
  }

  // Shared plumbing for "click this to open it, or drag it to change its
  // date(s)" on the same element. A plain click (no meaningful pointer
  // movement) calls `onClick`; anything past CLICK_THRESHOLD px counts as a
  // drag, calling `onPreview` on every move (to update the element's
  // position/size and show a live hint of what it would become) and
  // `onCommit` once on release (to persist it). Listeners live on `document`
  // so tracking continues even if the pointer outruns the element's edges.
  startBarInteraction(startEvent, { onClick, onPreview, onCommit }) {
    const CLICK_THRESHOLD_PX = 4
    let dragging = false
    let hint = null

    const onMouseMove = (event) => {
      if (!dragging) {
        const distance = Math.hypot(event.clientX - startEvent.clientX, event.clientY - startEvent.clientY)
        if (distance < CLICK_THRESHOLD_PX) return
        dragging = true
        hint = this.createDragHint()
      }
      this.positionDragHint(hint, event, onPreview(event))
    }

    const onMouseUp = (event) => {
      document.removeEventListener("mousemove", onMouseMove)
      document.removeEventListener("mouseup", onMouseUp)
      if (hint) hint.remove()

      if (dragging) {
        onCommit(event)
      } else {
        onClick()
      }
    }

    document.addEventListener("mousemove", onMouseMove)
    document.addEventListener("mouseup", onMouseUp)
  }

  createDragHint() {
    const hint = el("div", "fixed z-50 px-2 py-1 rounded bg-gray-900 text-white text-xs pointer-events-none shadow-lg tabular-nums")
    document.body.appendChild(hint)
    return hint
  }

  positionDragHint(hint, event, label) {
    hint.textContent = label
    hint.style.left = `${event.clientX + 14}px`
    hint.style.top = `${event.clientY + 14}px`
  }

  // Opens the same detail overlay the row label's own link opens — used for
  // a plain click on the bar/marker, which isn't a real <a> (it needs the
  // mousedown handler below for dragging instead of native link behavior).
  navigateToOverlay(href) {
    const link = document.createElement("a")
    link.href = href
    link.dataset.turboFrame = "modal_body"
    link.hidden = true
    document.body.appendChild(link)
    link.click()
    link.remove()
  }

  wireMilestoneDrag(marker, row, scale) {
    marker.addEventListener("mousedown", (event) => {
      event.preventDefault()
      const originalLeft = parseFloat(marker.style.left)
      const keyDates = this.keyDatesFor(row)

      // Tracks the mouse smoothly (raw pixels) until the date it would land
      // on comes within snapping range of a key date, at which point the
      // marker jumps to sit exactly on that date instead — same "magnet"
      // feel as design-tool snapping, rather than always moving in rigid
      // day-sized steps.
      const resolveDate = (moveEvent) => {
        const rawDeltaPx = moveEvent.clientX - event.clientX
        const deltaDays = Math.round(rawDeltaPx / scale.dayWidth)
        const rawDate = addDays(row.start, deltaDays)
        const snapped = this.snapDate(rawDate, keyDates)
        return { rawDeltaPx, date: snapped, snapped: isoDate(snapped) !== isoDate(rawDate) }
      }

      this.startBarInteraction(event, {
        onClick: () => this.navigateToOverlay(row.href),
        onPreview: (moveEvent) => {
          marker.classList.add("ring-2", "ring-indigo-400")
          const { rawDeltaPx, date, snapped } = resolveDate(moveEvent)
          marker.style.left = `${originalLeft + (snapped ? daysBetween(row.start, date) * scale.dayWidth : rawDeltaPx)}px`
          return isoDate(date)
        },
        onCommit: (upEvent) => {
          marker.classList.remove("ring-2", "ring-indigo-400")
          const { date } = resolveDate(upEvent)
          if (isoDate(date) === isoDate(row.start)) return
          this.persistItemDates(row, { date: isoDate(date) })
        }
      })
    })
  }

  wireBarMove(bar, row, scale) {
    bar.addEventListener("mousedown", (event) => {
      if (event.target !== bar) return // let the resize handles handle their own interaction
      event.preventDefault()
      const originalLeft = parseFloat(bar.style.left)
      const keyDates = this.keyDatesFor(row)

      // A move keeps the task's length, so both edges shift by the same
      // amount — snap whichever edge is actually close to a key date (start
      // takes priority if, unusually, both are) and apply that adjustment to
      // both, rather than snapping each edge independently and stretching
      // the bar.
      const resolveDelta = (moveEvent) => {
        const rawDeltaPx = moveEvent.clientX - event.clientX
        const deltaDays = Math.round(rawDeltaPx / scale.dayWidth)
        const rawStart = addDays(row.start, deltaDays)
        const rawEnd = addDays(row.end, deltaDays)
        // Whether something is nearby has to be checked independently of the
        // resulting adjustment: if the raw start already lands exactly on a
        // key date, its adjustment is 0 — indistinguishable from "nothing
        // nearby" by adjustment alone, which would wrongly let the end's
        // snap take over even though the start should win.
        const startNearby = keyDates.some((keyDate) => Math.abs(daysBetween(rawStart, keyDate)) <= SNAP_THRESHOLD_DAYS)
        const endNearby = keyDates.some((keyDate) => Math.abs(daysBetween(rawEnd, keyDate)) <= SNAP_THRESHOLD_DAYS)
        if (startNearby) {
          const adjustment = daysBetween(rawStart, this.snapDate(rawStart, keyDates))
          return { rawDeltaPx, deltaDays: deltaDays + adjustment, snapped: true }
        }
        if (endNearby) {
          const adjustment = daysBetween(rawEnd, this.snapDate(rawEnd, keyDates))
          return { rawDeltaPx, deltaDays: deltaDays + adjustment, snapped: true }
        }
        return { rawDeltaPx, deltaDays, snapped: false }
      }

      this.startBarInteraction(event, {
        onClick: () => this.navigateToOverlay(row.href),
        onPreview: (moveEvent) => {
          bar.classList.add("ring-2", "ring-indigo-400")
          const { rawDeltaPx, deltaDays, snapped } = resolveDelta(moveEvent)
          bar.style.left = `${originalLeft + (snapped ? deltaDays * scale.dayWidth : rawDeltaPx)}px`
          return `${isoDate(addDays(row.start, deltaDays))} → ${isoDate(addDays(row.end, deltaDays))}`
        },
        onCommit: (upEvent) => {
          bar.classList.remove("ring-2", "ring-indigo-400")
          const { deltaDays } = resolveDelta(upEvent)
          if (deltaDays === 0) return
          this.persistItemDates(row, {
            start_date: isoDate(addDays(row.start, deltaDays)),
            end_date: isoDate(addDays(row.end, deltaDays))
          })
        }
      })
    })
  }

  wireBarResize(handle, bar, row, scale, edge) {
    handle.addEventListener("mousedown", (event) => {
      event.preventDefault()
      event.stopPropagation() // don't also start a whole-bar move
      const originalLeft = parseFloat(bar.style.left)
      const originalWidth = parseFloat(bar.style.width)
      const keyDates = this.keyDatesFor(row)

      // Snaps the moving edge to a nearby key date, then clamps against the
      // *other*, fixed edge exactly as before (a start can't pass its own
      // end, and vice versa) — snapping is resolved first so a snap can't
      // itself produce an invalid range.
      const resolveEdgeDate = (moveEvent) => {
        const deltaDays = Math.round((moveEvent.clientX - event.clientX) / scale.dayWidth)
        if (edge === "start") {
          const snapped = this.snapDate(addDays(row.start, deltaDays), keyDates)
          return snapped > row.end ? row.end : snapped
        }
        const snapped = this.snapDate(addDays(row.end, deltaDays), keyDates)
        return snapped < row.start ? row.start : snapped
      }

      this.startBarInteraction(event, {
        onClick: () => this.navigateToOverlay(row.href),
        onPreview: (moveEvent) => {
          bar.classList.add("ring-2", "ring-indigo-400")
          const date = resolveEdgeDate(moveEvent)
          if (edge === "start") {
            const finalDeltaDays = daysBetween(row.start, date)
            const newWidth = Math.max(scale.dayWidth, originalWidth - finalDeltaDays * scale.dayWidth)
            bar.style.left = `${originalLeft + (originalWidth - newWidth)}px`
            bar.style.width = `${newWidth}px`
          } else {
            const finalDeltaDays = daysBetween(row.end, date)
            bar.style.width = `${Math.max(scale.dayWidth, originalWidth + finalDeltaDays * scale.dayWidth)}px`
          }
          return isoDate(date)
        },
        onCommit: (upEvent) => {
          bar.classList.remove("ring-2", "ring-indigo-400")
          const date = resolveEdgeDate(upEvent)

          if (edge === "start") {
            if (isoDate(date) === isoDate(row.start)) return
            this.persistItemDates(row, { start_date: isoDate(date) })
          } else {
            if (isoDate(date) === isoDate(row.end)) return
            this.persistItemDates(row, { end_date: isoDate(date) })
          }
        }
      })
    })
  }

  // Saves a moved/resized milestone or task through its existing show/update
  // endpoint (the same one the detail overlay's own form uses), keeps the
  // in-memory payload in step on success the same way `syncOrder` does for
  // reordering, and explicitly re-renders — rather than counting solely on
  // the projectsValueChanged callback, which fires off the back of Stimulus's
  // own attribute-change detection and isn't something to stake a visible,
  // immediate UI update on. On failure, re-renders from the last-known-good
  // data so the bar snaps back instead of being left showing an unsaved
  // position that a later reload would silently disagree with.
  persistItemDates(row, attrs) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    const paramKey = row.type === "milestone" ? "milestone" : "task"

    fetch(row.href, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken, Accept: "application/json" },
      body: JSON.stringify({ [paramKey]: attrs })
    })
      .then((response) => {
        if (!response.ok) throw new Error(`save failed (${response.status})`)
        return response.json()
      })
      // Syncs from the server's own gantt_attributes rather than the attrs
      // this request sent — harmless here since nothing about a date change
      // has server-derived side effects, but it's the same response shape
      // handleItemSaved (TASK-051) relies on for fields that do, like team.
      .then((serverAttrs) => {
        this.syncItemDates(row, serverAttrs)
        this.refresh()
      })
      .catch((error) => {
        console.error("Failed to save new date(s)", error)
        this.refresh()
      })
  }

  syncItemDates(row, attrs) {
    const [ kind, projectId ] = row.sortableGroup.split("-")
    this.projectsValue = this.projectsValue.map((project) => {
      if (String(project.id) !== projectId) return project
      return {
        ...project,
        [kind]: project[kind].map((item) => (String(item.id) === String(row.sortableId) ? { ...item, ...attrs } : item))
      }
    })
  }

  // Sprints are individually stored records now, so this is just a filter
  // over whatever overlaps the visible date range.
  sprintsCovering(rangeStart, rangeEnd) {
    return this.sprintsValue
      .map((s) => ({ number: s.number, start: parseDate(s.start_date), end: parseDate(s.end_date) }))
      .filter((s) => s.end >= rangeStart && s.start <= rangeEnd)
      .sort((a, b) => a.number - b.number)
  }
}
