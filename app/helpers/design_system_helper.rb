module DesignSystemHelper
  BUTTON_VARIANTS = {
    primary: "text-sm px-3 py-1.5 rounded bg-indigo-600 text-white hover:bg-indigo-500 cursor-pointer",
    dark: "text-sm px-3 py-1.5 rounded bg-gray-900 text-white hover:bg-gray-700 cursor-pointer",
    danger: "text-sm px-3 py-1.5 rounded bg-red-600 text-white hover:bg-red-500 cursor-pointer",
    danger_text: "text-sm text-red-600 hover:underline bg-transparent p-0 cursor-pointer",
    ghost: "text-xs px-2 py-1 rounded border border-gray-300 text-gray-600 hover:bg-gray-50 cursor-pointer",
    # Match the milestone/task color coding used throughout (amber ◆ / blue ▬).
    milestone: "text-sm px-3 py-1.5 rounded bg-amber-500 text-white hover:bg-amber-400 cursor-pointer",
    task: "text-sm px-3 py-1.5 rounded bg-blue-600 text-white hover:bg-blue-500 cursor-pointer"
  }.freeze

  ALERT_VARIANTS = {
    error: "text-sm text-red-700 bg-red-50 border border-red-200 rounded px-3 py-2",
    success: "text-sm text-emerald-700 bg-emerald-50 border border-emerald-200 rounded px-3 py-2"
  }.freeze

  # Status badges for the project report (TASK-053) — matches Task#status /
  # Milestone#status, which is purely date-driven. Colors chosen to read
  # clearly as a small pill: blue for active, red for overdue, gray for not
  # started. Verification (confirmed with management) is a separate signal,
  # shown as its own checkmark rather than folded into this.
  STATUS_VARIANTS = {
    in_progress: "text-blue-700 bg-blue-50 border border-blue-200",
    overdue: "text-red-700 bg-red-50 border border-red-200",
    upcoming: "text-gray-600 bg-gray-50 border border-gray-200"
  }.freeze

  # Buttons, submits and delete links across the app share these looks —
  # pass the variant instead of retyping the Tailwind classes each time.
  def ds_button(variant = :primary)
    BUTTON_VARIANTS.fetch(variant)
  end

  # Flash-style banners (used both for real flash messages and inline form
  # errors) come in exactly these two flavors.
  def ds_alert(variant = :error)
    ALERT_VARIANTS.fetch(variant)
  end

  # Every text/date/number/textarea input gets its border, padding, radius and
  # focus ring from the base layer (see application.css) automatically and
  # defaults to full width — this only needs to override width for side-by-
  # side fields (e.g. a start/end date pair). Returns nil (no class attribute
  # rendered) for the common full-width case.
  def ds_field(width: nil)
    width
  end

  def ds_section_label
    "text-xs font-semibold uppercase tracking-wide text-gray-500"
  end

  def ds_status_badge(status)
    "text-xs px-2 py-0.5 rounded-full whitespace-nowrap #{STATUS_VARIANTS.fetch(status)}"
  end

  def ds_status_label(status)
    status.to_s.tr("_", " ").capitalize
  end
end
