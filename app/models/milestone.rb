class Milestone < ApplicationRecord
  belongs_to :project

  before_create :append_position

  validates :name, presence: true
  validates :date, presence: true
  validate :locked_fields_unchanged_once_verified

  # Same purpose as Task#gantt_attributes — see there.
  def gantt_attributes
    { id: id, name: name, date: date.iso8601, verified: verified }
  end

  # Same purpose as Task#status — see there. A milestone has no duration, so
  # "in progress" only applies on the exact day itself.
  def status
    return :upcoming if date > Date.current
    return :overdue if date < Date.current

    :in_progress
  end

  private

  def append_position
    self.position = project.milestones.maximum(:position).to_i + 1
  end

  # Same purpose as Task#locked_fields_unchanged_once_verified — see there.
  def locked_fields_unchanged_once_verified
    return unless verified_was && verified?
    return unless name_changed? || date_changed?

    errors.add(:base, "Verified milestones can't have their name or date changed — un-verify it first.")
  end
end
