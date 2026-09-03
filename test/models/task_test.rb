require "test_helper"

class TaskTest < ActiveSupport::TestCase
  test "team is optional" do
    project = Project.create!(name: "Demo")
    task = project.tasks.new(name: "Untitled", start_date: Date.current, end_date: Date.current)
    assert task.valid?
    assert_nil task.team
  end

  test "gantt_attributes matches the shape the Gantt chart's JS expects" do
    project = Project.create!(name: "Demo")
    team = Team.create!(name: "Launchpad", color: "#f97316")
    task = project.tasks.create!(name: "UAT", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 5), team: team, verified: true)

    assert_equal(
      { id: task.id, name: "UAT", start_date: "2026-01-01", end_date: "2026-01-05",
        team_id: team.id, team_name: "Launchpad", team_color: "#f97316", verified: true },
      task.gantt_attributes
    )
  end

  test "gantt_attributes has nil team fields when no team is assigned" do
    project = Project.create!(name: "Demo")
    task = project.tasks.create!(name: "UAT", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 5))

    attrs = task.gantt_attributes
    assert_nil attrs[:team_id]
    assert_nil attrs[:team_name]
    assert_nil attrs[:team_color]
  end

  test "a verified task rejects changes to its name or dates" do
    project = Project.create!(name: "Demo")
    task = project.tasks.create!(name: "UAT", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 5), verified: true)

    assert_not task.update(name: "Renamed")
    assert_includes task.errors[:base].join, "can't have their name or dates changed"

    task.reload
    assert_not task.update(start_date: Date.new(2026, 1, 2), end_date: Date.new(2026, 1, 6))
    assert_includes task.errors[:base].join, "can't have their name or dates changed"
  end

  test "a verified task still allows notes and team changes" do
    project = Project.create!(name: "Demo")
    team = Team.create!(name: "Launchpad", color: "#f97316")
    task = project.tasks.create!(name: "UAT", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 5), verified: true)

    assert task.update(notes: "reviewed", team: team)
    assert_equal "reviewed", task.reload.notes
    assert_equal team, task.team
  end

  test "un-verifying a task in the same save as a name/date change is allowed" do
    project = Project.create!(name: "Demo")
    task = project.tasks.create!(name: "UAT", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 5), verified: true)

    assert task.update(verified: false, name: "Renamed")
    assert_equal "Renamed", task.reload.name
    assert_not task.verified?
  end

  test "an unverified task can freely change its name and dates" do
    project = Project.create!(name: "Demo")
    task = project.tasks.create!(name: "UAT", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 5))

    assert task.update(name: "Renamed", start_date: Date.new(2026, 1, 3), end_date: Date.new(2026, 1, 8))
  end

  test "status is upcoming, in_progress, or overdue based on dates alone" do
    project = Project.create!(name: "Demo")
    upcoming = project.tasks.create!(name: "Later", start_date: Date.current + 5, end_date: Date.current + 10)
    in_progress = project.tasks.create!(name: "Now", start_date: Date.current - 2, end_date: Date.current + 2)
    overdue = project.tasks.create!(name: "Late", start_date: Date.current - 10, end_date: Date.current - 1)

    assert_equal :upcoming, upcoming.status
    assert_equal :in_progress, in_progress.status
    assert_equal :overdue, overdue.status
  end

  test "verified does not change status — it's a separate signal from date-based status" do
    project = Project.create!(name: "Demo")
    task = project.tasks.create!(name: "Late but confirmed", start_date: Date.current - 10, end_date: Date.current - 1, verified: true)

    assert_equal :overdue, task.status
    assert task.verified?
  end
end
