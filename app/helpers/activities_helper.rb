module ActivitiesHelper
  # Dot color per trackable type — echoes the color already used for that
  # type elsewhere (milestone amber ◆, task blue ▬; project/team/sprint have
  # no established color elsewhere, so these are new but distinct).
  TYPE_DOT_COLORS = {
    "Milestone" => "bg-amber-500",
    "Task" => "bg-blue-600",
    "Project" => "bg-gray-800",
    "Team" => "bg-gray-400",
    "Sprint" => "bg-indigo-400"
  }.freeze

  ACTION_LABELS = {
    "created" => [ "created", "text-emerald-600" ],
    "updated" => [ "updated", "text-gray-500" ],
    "deleted" => [ "deleted", "text-red-600" ],
    "imported" => [ "imported", "text-violet-600" ]
  }.freeze

  def activity_type_badge(type)
    dot = tag.span("", class: "inline-block w-2 h-2 rounded-full #{TYPE_DOT_COLORS.fetch(type, 'bg-gray-400')}")
    tag.span(safe_join([ dot, type ], " "), class: "inline-flex items-center gap-1 text-xs text-gray-500")
  end

  def activity_action_label(action)
    label, color_class = ACTION_LABELS.fetch(action, [ action, "text-gray-500" ])
    tag.span(label, class: "text-xs #{color_class}")
  end
end
