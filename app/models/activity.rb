class Activity < ApplicationRecord
  # Callback-driven attributes that aren't a "change" a human made — a diff
  # that's only these is treated as no-op and never logged. `position` is
  # excluded too, but in practice never appears here: every place that sets
  # it (reorder endpoints, append_position) uses update_all/update_columns,
  # which don't run callbacks at all.
  IGNORED_ATTRIBUTES = %w[created_at updated_at position].freeze

  validates :trackable_type, :trackable_id, :trackable_name, :action, presence: true

  def self.ordered
    order(created_at: :desc, id: :desc)
  end

  # Suppresses logging for the duration of the block — for bulk operations
  # (data import) where a per-record entry for every row would bury
  # whatever a human actually changed. The caller logs one summary entry
  # instead; see DataTransfersController#import.
  def self.suppress
    previous = Thread.current[:activity_suppressed]
    Thread.current[:activity_suppressed] = true
    yield
  ensure
    Thread.current[:activity_suppressed] = previous
  end

  def self.suppressed?
    Thread.current[:activity_suppressed] == true
  end

  # `changes` is a saved_changes-shaped hash (attr => [before, after]); pass
  # nil for "created"/"deleted", where there's nothing to diff.
  def self.log(record, action, changes: nil)
    return if suppressed?

    details = changes.present? ? summarize(changes) : nil
    return if action == "updated" && details.blank?

    create!(
      trackable_type: record.class.name,
      trackable_id: record.id,
      trackable_name: record.activity_label,
      project_name: record.try(:activity_project_name),
      action: action,
      details: details
    )
  end

  def self.summarize(changes)
    changes.except(*IGNORED_ATTRIBUTES).filter_map do |attribute, (before, after)|
      next if before == after

      "#{attribute.humanize}: #{format_value(before)} → #{format_value(after)}"
    end.join("; ").presence
  end

  def self.format_value(value)
    case value
    when nil then "—"
    when true then "Yes"
    when false then "No"
    else value.to_s
    end
  end
end
