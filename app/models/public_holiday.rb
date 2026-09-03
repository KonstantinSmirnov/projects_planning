# Thin wrapper around the `holidays` gem — not an ActiveRecord model, there's
# nothing to persist. Dates are computed on demand for a fixed set of regions.
class PublicHoliday
  REGIONS = {
    in: "India",
    kz: "Kazakhstan",
    my: "Malaysia",
    pl: "Poland",
    us: "USA",
    vn: "Vietnam"
  }.freeze

  # Chosen to stay clear of colors already meaningful elsewhere on the Gantt
  # chart: amber (milestones), blue (tasks / code freeze), violet (submit to
  # store), green (publish), red (today line), indigo (active controls).
  REGION_COLORS = {
    in: "bg-orange-500",
    kz: "bg-cyan-500",
    my: "bg-pink-500",
    pl: "bg-rose-500",
    us: "bg-sky-500",
    vn: "bg-lime-500"
  }.freeze

  # The `holidays` gem only computes fixed/civil dates — it has no support
  # for holidays set by lunar/lunisolar calendars, so neither Diwali (Hindu
  # lunisolar) nor Chinese New Year (Chinese lunisolar) show up in its `:in`/
  # `:my` definitions. Dates below are the published dates for each year,
  # since there's no formula to derive them; extend these lists as the app's
  # date range grows into new years.
  SUPPLEMENTAL = {
    in: {
      Date.new(2024, 10, 31) => "Diwali",
      Date.new(2025, 10, 20) => "Diwali",
      Date.new(2026, 11, 8) => "Diwali",
      Date.new(2027, 10, 29) => "Diwali",
      Date.new(2028, 10, 17) => "Diwali",
      Date.new(2029, 11, 5) => "Diwali"
    },
    my: {
      # Malaysia observes both days nationwide (Kelantan/Terengganu drop the
      # second day, but this app doesn't model per-state holidays).
      Date.new(2024, 2, 10) => "Chinese New Year (Day 1)",
      Date.new(2024, 2, 11) => "Chinese New Year (Day 2)",
      Date.new(2025, 1, 29) => "Chinese New Year (Day 1)",
      Date.new(2025, 1, 30) => "Chinese New Year (Day 2)",
      Date.new(2026, 2, 17) => "Chinese New Year (Day 1)",
      Date.new(2026, 2, 18) => "Chinese New Year (Day 2)",
      Date.new(2027, 2, 6) => "Chinese New Year (Day 1)",
      Date.new(2027, 2, 7) => "Chinese New Year (Day 2)",
      Date.new(2028, 1, 26) => "Chinese New Year (Day 1)",
      Date.new(2028, 1, 27) => "Chinese New Year (Day 2)",
      Date.new(2029, 2, 13) => "Chinese New Year (Day 1)",
      Date.new(2029, 2, 14) => "Chinese New Year (Day 2)"
    }
  }.freeze

  attr_reader :date, :name, :region

  def initialize(date:, name:, region:)
    @date = date
    @name = name
    @region = region
  end

  def region_label
    REGIONS.fetch(region)
  end

  def region_color
    REGION_COLORS.fetch(region)
  end

  def self.all_for(start_date, end_date, regions: REGIONS.keys)
    from_gem = regions.flat_map do |region|
      Holidays.between(start_date, end_date, region).map do |h|
        new(date: h[:date].to_date, name: h[:name], region: region)
      end
    end

    from_supplemental = regions.flat_map do |region|
      (SUPPLEMENTAL[region] || {}).filter_map do |date, name|
        new(date: date, name: name, region: region) if date.between?(start_date, end_date)
      end
    end

    (from_gem + from_supplemental).sort_by { |holiday| [ holiday.date, holiday.region_label ] }
  end

  # A generous window around every date actually in use, so a fixed
  # server-side query comfortably covers whatever range the Gantt chart ends
  # up rendering client-side (it pads its own range independently).
  def self.default_range
    dates = Milestone.pluck(:date) +
      Task.pluck(:start_date, :end_date).flatten +
      Sprint.pluck(:start_date, :end_date).flatten
    dates.compact!

    return [ Date.current.beginning_of_year - 1.year, Date.current.end_of_year + 1.year ] if dates.empty?

    [ dates.min - 1.year, dates.max + 1.year ]
  end
end
