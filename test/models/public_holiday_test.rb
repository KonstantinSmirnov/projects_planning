require "test_helper"

class PublicHolidayTest < ActiveSupport::TestCase
  test "all_for returns holidays for every configured region, sorted by date" do
    holidays = PublicHoliday.all_for(Date.new(2026, 1, 1), Date.new(2026, 1, 31))

    assert holidays.any?
    assert_equal PublicHoliday::REGIONS.keys.sort, holidays.map(&:region).uniq.sort
    assert_equal holidays.map(&:date).sort, holidays.map(&:date)
  end

  test "all_for can be scoped to a subset of regions" do
    holidays = PublicHoliday.all_for(Date.new(2026, 1, 1), Date.new(2026, 1, 31), regions: [ :us ])

    assert holidays.any?
    assert_equal [ :us ], holidays.map(&:region).uniq
  end

  test "includes Diwali for India, which the holidays gem doesn't compute on its own" do
    holidays = PublicHoliday.all_for(Date.new(2026, 1, 1), Date.new(2026, 12, 31), regions: [ :in ])

    diwali = holidays.find { |h| h.name == "Diwali" }
    assert diwali, "Diwali should appear in India's holiday list"
    assert_equal Date.new(2026, 11, 8), diwali.date
  end

  test "supplemental holidays are excluded outside the requested date range" do
    holidays = PublicHoliday.all_for(Date.new(2026, 1, 1), Date.new(2026, 1, 31), regions: [ :in ])
    assert_not holidays.any? { |h| h.name == "Diwali" }
  end

  test "includes both days of Chinese New Year for Malaysia, which the holidays gem doesn't compute on its own" do
    holidays = PublicHoliday.all_for(Date.new(2026, 1, 1), Date.new(2026, 12, 31), regions: [ :my ])

    assert_equal Date.new(2026, 2, 17), holidays.find { |h| h.name == "Chinese New Year (Day 1)" }&.date
    assert_equal Date.new(2026, 2, 18), holidays.find { |h| h.name == "Chinese New Year (Day 2)" }&.date
  end

  test "region_label and region_color are defined for every region" do
    PublicHoliday::REGIONS.each_key do |region|
      holiday = PublicHoliday.new(date: Date.current, name: "Test", region: region)
      assert_kind_of String, holiday.region_label
      assert_match(/\Abg-\w+-500\z/, holiday.region_color)
    end
  end

  test "default_range falls back to a window around today when there's no data" do
    Milestone.delete_all
    Task.delete_all
    Sprint.delete_all
    Project.delete_all

    start_date, end_date = PublicHoliday.default_range

    assert start_date <= Date.current
    assert end_date >= Date.current
  end

  test "default_range spans a year on either side of the earliest/latest known date" do
    Sprint.delete_all
    Sprint.create!(number: 1, start_date: Date.new(2026, 6, 1), end_date: Date.new(2026, 6, 14))

    start_date, end_date = PublicHoliday.default_range

    assert start_date <= Date.new(2025, 6, 1)
    assert end_date >= Date.new(2027, 6, 14)
  end
end
