require "test_helper"

class TeamsConfigurationTest < ActionDispatch::IntegrationTest
  setup do
    Team.delete_all
    @team = Team.create!(name: "Launchpad", color: "#f97316")
  end

  test "the overlay lists every team with a name field and a color field" do
    get teams_path
    assert_response :success
    assert_select "input[name=?]", "teams[#{@team.id}][name]"
    assert_select "input[type=color][name=?]", "teams[#{@team.id}][color]"
  end

  # TASK-038 rework: unlike Sprints configuration (TASK-031), Save here is
  # meant to close the overlay, so every form/button targets `_top`.
  test "every team form/button targets _top so saving closes the overlay" do
    get teams_path
    assert_select "form#teams_save_form[data-turbo-frame=?]", "_top"
    # button_to puts `data-*` on the submitter button, not the form — Turbo
    # reads the frame target from the submitter first, so this is where it
    # actually takes effect.
    assert_select "form[action=?] button[data-turbo-frame=?]", team_path(@team), "_top"
    assert_select "form#teams_save_form" do
      assert_select "input[type=text], input[type=color], input[type=submit]", false
    end
  end

  test "add team creates one with placeholder defaults" do
    assert_difference("Team.count", 1) do
      post teams_path
    end
    assert_redirected_to root_path
  end

  test "saving updates every changed row in one request" do
    other = Team.create!(name: "NativeX", color: "#8b5cf6")

    patch teams_path, params: {
      teams: {
        @team.id.to_s => { name: "Launchpad Renamed", color: "#111111" },
        other.id.to_s => { name: "NativeX", color: "#222222" }
      }
    }
    assert_redirected_to root_path

    assert_equal "Launchpad Renamed", @team.reload.name
    assert_equal "#111111", @team.color
    assert_equal "#222222", other.reload.color
  end

  test "an invalid color is rejected and shown inline" do
    patch teams_path, params: { teams: { @team.id.to_s => { name: "Launchpad", color: "not-a-color" } } }
    follow_redirect!
    assert_select "p", text: /hex color/
    assert_not_equal "not-a-color", @team.reload.color
  end

  test "deleting a team removes it" do
    delete team_path(@team)
    assert_redirected_to root_path
    assert_not Team.exists?(@team.id)
  end
end
