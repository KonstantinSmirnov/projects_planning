class Task < ApplicationRecord
  belongs_to :project
  belongs_to :team, optional: true

  before_create :append_position

  validates :name, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date
  validate :locked_fields_unchanged_once_verified

  # The shape sent to the Gantt chart's client-side JS — both in the initial
  # page-load payload (ProjectsHelper#gantt_projects_payload) and as the
  # response to a live in-place update (see TasksController#update), so the
  # two never drift out of sync with each other.
  def gantt_attributes
    { id: id, name: name, start_date: start_date.iso8601, end_date: end_date.iso8601,
      team_id: team_id, team_name: team&.name, team_color: team&.color, verified: verified }
  end

  # For the project status report (TASK-053) — derived purely from dates.
  # `verified` is a separate signal (confirmed with management) and doesn't
  # feed into this: a verified task keeps showing as overdue/in_progress/
  # upcoming based on its actual dates, same as an unverified one.
  def status
    return :upcoming if start_date > Date.current
    return :overdue if end_date < Date.current

    :in_progress
  end

  private

  def append_position
    self.position = project.tasks.maximum(:position).to_i + 1
  end

  def end_date_after_start_date
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "must be on or after the start date") if end_date < start_date
  end

  # A verified task's title/dates are locked — un-verify it first (in the
  # same save or an earlier one) to change them. Notes and team assignment
  # stay editable regardless, since those aren't the "core facts" verification
  # is meant to freeze.
  def locked_fields_unchanged_once_verified
    return unless verified_was && verified?
    return unless name_changed? || start_date_changed? || end_date_changed?

    errors.add(:base, "Verified tasks can't have their name or dates changed — un-verify it first.")
  end
end
