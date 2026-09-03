require "test_helper"

class SettingsMenuTest < ActionDispatch::IntegrationTest
  test "Sprints, Teams, Activity, Export and Import live under one Settings menu" do
    get root_path
    assert_response :success

    assert_select "div[data-controller=dropdown] button", text: /Settings/
    assert_select "div[data-dropdown-target=menu] a[href=?]", sprints_path
    assert_select "div[data-dropdown-target=menu] a[href=?]", teams_path
    assert_select "div[data-dropdown-target=menu] a[href=?]", activities_path
    assert_select "div[data-dropdown-target=menu] a[href=?]", export_data_path
    assert_select "div[data-dropdown-target=menu] a[href=?]", new_data_import_path
  end

  test "Holidays and Design system stay outside the Settings menu" do
    get root_path

    assert_select "nav > a[href=?]", public_holidays_path
    assert_select "nav > a[href=?]", design_system_path
  end
end
