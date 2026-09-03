class Project < ApplicationRecord
  include Trackable

  has_many :milestones, -> { order(:position) }, dependent: :destroy
  has_many :tasks, -> { order(:position) }, dependent: :destroy

  before_create :append_position

  validates :name, presence: true

  # Reads through the loaded associations rather than issuing four extra
  # aggregate queries per project on the index page.
  def start_date
    [ tasks.map(&:start_date).min, milestones.map(&:date).min ].compact.min
  end

  def end_date
    [ tasks.map(&:end_date).max, milestones.map(&:date).max ].compact.max
  end

  def date_range?
    start_date.present? && end_date.present?
  end

  def activity_label
    name
  end

  private

  def append_position
    self.position = Project.maximum(:position).to_i + 1
  end
end
