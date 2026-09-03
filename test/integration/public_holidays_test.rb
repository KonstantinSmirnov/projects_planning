require "test_helper"

class PublicHolidaysTest < ActionDispatch::IntegrationTest
  test "the overlay lists holidays across every configured region" do
    get public_holidays_path
    assert_response :success

    PublicHoliday::REGIONS.each_value do |label|
      assert_select "span", text: label
    end
  end

  test "the header link to the overlay targets the modal frame, not the top" do
    get root_path
    assert_select "a[href=?][data-turbo-frame=?]", public_holidays_path, "modal_body"
  end

  # TASK-032: clicking a holiday marker on the Gantt chart links to this with
  # ?date= to scope the overlay to just that date's holiday(s).
  test "a date filter scopes the overlay to only that date's holidays" do
    get public_holidays_path(date: "2026-01-01")
    assert_response :success

    assert_select "h3", text: "Holidays on January 1, 2026"
    PublicHoliday.all_for(Date.new(2026, 1, 1), Date.new(2026, 1, 1)).each do |holiday|
      assert_select "span", text: holiday.name
    end
    assert_select "a", text: "View all holidays"
  end

  test "an invalid date filter falls back to the full list" do
    get public_holidays_path(date: "not-a-date")
    assert_response :success
    assert_select "h3", text: "Public holidays"
  end
end
