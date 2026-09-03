# Logs every create/update/destroy of the including model to Activity — see
# TASK-060. `after_*_commit` (not the plain `after_*` callbacks) so a change
# that gets rolled back (a failed transaction elsewhere, e.g. Sprint
# renumbering) never leaves a log entry for something that didn't actually
# happen.
#
# Including models must implement `activity_label` (a short display name,
# e.g. a task's name or "Sprint 12") and may override `activity_project_name`
# (nil by default — only Project/Milestone/Task belong to one).
module Trackable
  extend ActiveSupport::Concern

  included do
    after_create_commit { Activity.log(self, "created") }
    after_update_commit :log_activity_update
    after_destroy_commit { Activity.log(self, "deleted") }
  end

  def activity_project_name
    nil
  end

  # Override to reshape saved_changes before it's summarized — e.g. Task
  # swaps a raw team_id before/after for team names.
  def activity_changes
    saved_changes
  end

  private

  def log_activity_update
    Activity.log(self, "updated", changes: activity_changes)
  end
end
