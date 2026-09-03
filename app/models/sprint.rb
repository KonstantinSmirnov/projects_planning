class Sprint < ApplicationRecord
  include Trackable

  DEFAULT_LENGTH_DAYS = 14
  SEED_THROUGH = Date.new(2027, 12, 31)
  TUESDAY = 2
  WEDNESDAY = 3
  FRIDAY = 5

  validates :number, presence: true, numericality: { only_integer: true, greater_than: 0 }, uniqueness: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_on_or_after_start

  def self.ordered
    order(:number)
  end

  def self.ensure_seeded!
    generate_from!(next_tuesday_on_or_after(Date.current)) if none?
  end

  # Creates sprints 1, 2, 3... at a fixed 2-week cadence from `start_date`
  # until at least `through` is covered.
  def self.generate_from!(start_date, through: SEED_THROUGH)
    number = 1
    cursor = start_date
    while cursor <= through
      create!(number: number, start_date: cursor, end_date: cursor + (DEFAULT_LENGTH_DAYS - 1))
      number += 1
      cursor += DEFAULT_LENGTH_DAYS
    end
  end

  # Appends a new sprint right after the current last one. Defaults to a
  # Tuesday start (the next one on or after the day the last sprint ends) as
  # a smart guess — the row is immediately editable if that's not right.
  def self.add_next!
    last = ordered.last
    return ensure_seeded! unless last

    start_date = next_tuesday_on_or_after(last.end_date + 1)
    create!(number: last.number + 1, start_date: start_date, end_date: start_date + (DEFAULT_LENGTH_DAYS - 1))
  end

  # The whole sequence is renumbered from the first sprint: you set where
  # numbering starts and everything after it follows on incrementally, so the
  # list can never end up with gaps or duplicates.
  def self.renumber_from!(first_number)
    first_number = begin
      Integer(first_number)
    rescue ArgumentError, TypeError
      raise ArgumentError, "Sprint number must be a whole number."
    end
    raise ArgumentError, "Sprint number must be 1 or greater." if first_number < 1

    sprints = ordered.to_a
    return if sprints.empty? || sprints.first.number == first_number

    transaction do
      # Two passes. The first parks every row above the current maximum so the
      # unique index on `number` can't trip while values slide past each other
      # (shifting 1,2,3 up to 2,3,4 one row at a time would collide otherwise).
      parking = maximum(:number).to_i + first_number + sprints.size
      sprints.each_with_index { |sprint, index| sprint.update_columns(number: parking + index) }
      sprints.each_with_index { |sprint, index| sprint.update_columns(number: first_number + index) }
    end
  end

  def self.next_tuesday_on_or_after(date)
    date + ((TUESDAY - date.wday) % 7)
  end

  def self.for_date(date = Date.current)
    find_by("start_date <= ? AND end_date >= ?", date, date)
  end

  # Only the first or last sprint can be removed, so numbering never gets
  # gaps in the middle.
  def deletable?
    boundary_numbers = [ Sprint.minimum(:number), Sprint.maximum(:number) ]
    boundary_numbers.include?(number)
  end

  # Only meaningful when `release?` is true — derived purely from this
  # sprint's own start date, not stored separately.
  def code_freeze_date
    start_date
  end

  def submit_to_store_date
    day_in_week(start_date, FRIDAY)
  end

  def publish_date
    day_in_week(start_date + 7, WEDNESDAY)
  end

  def activity_label
    "Sprint #{number}"
  end

  private

  # The occurrence of `wday` (0 = Sunday .. 6 = Saturday) within the 7-day
  # window starting at `week_start`, regardless of what day `week_start`
  # itself falls on.
  def day_in_week(week_start, wday)
    week_start + ((wday - week_start.wday) % 7)
  end

  def end_on_or_after_start
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "must be on or after the start date") if end_date < start_date
  end
end
