class PublicHolidaysController < ApplicationController
  # Clicking a marker on the Gantt chart's holiday row links here with
  # `?date=` to scope the overlay to just that date's holiday(s) — otherwise
  # (the header's "Holidays" link) it lists the whole default range.
  def index
    @filter_date = parse_date(params[:date])

    if @filter_date
      @start_date = @end_date = @filter_date
    else
      @start_date, @end_date = PublicHoliday.default_range
    end

    @holidays = PublicHoliday.all_for(@start_date, @end_date)
  end

  private

  def parse_date(value)
    Date.iso8601(value) if value.present?
  rescue ArgumentError
    nil
  end
end
