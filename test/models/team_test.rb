require "test_helper"

class TeamTest < ActiveSupport::TestCase
  test "ensure_seeded! creates the 3 defaults only when the table is empty" do
    Team.delete_all
    Team.ensure_seeded!
    assert_equal [ "Commerce", "Launchpad", "NativeX" ], Team.ordered.pluck(:name)

    Team.ensure_seeded!
    assert_equal 3, Team.count, "must not duplicate when teams already exist"
  end

  test "requires a name and a valid hex color" do
    assert_not Team.new(color: "#3b82f6").valid?, "name is required"
    assert_not Team.new(name: "QA", color: "blue").valid?, "color must be a hex value"
    assert_not Team.new(name: "QA", color: "#zzzzzz").valid?, "color must be valid hex digits"
    assert Team.new(name: "QA", color: "#3b82f6").valid?
  end

  test "team names must be unique" do
    Team.create!(name: "QA", color: "#3b82f6")
    duplicate = Team.new(name: "QA", color: "#10b981")
    assert_not duplicate.valid?
  end

  test "deleting a team nullifies its tasks' team_id rather than destroying them" do
    project = Project.create!(name: "Demo")
    team = Team.create!(name: "QA", color: "#3b82f6")
    task = project.tasks.create!(name: "Test pass", start_date: Date.current, end_date: Date.current + 1, team: team)

    team.destroy

    assert Task.exists?(task.id), "the task itself must survive"
    assert_nil task.reload.team_id
  end
end
