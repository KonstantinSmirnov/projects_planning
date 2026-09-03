require "test_helper"

class MilestoneTest < ActiveSupport::TestCase
  test "gantt_attributes matches the shape the Gantt chart's JS expects" do
    project = Project.create!(name: "Demo")
    milestone = project.milestones.create!(name: "Go live", date: Date.new(2026, 1, 1), verified: true)

    assert_equal(
      { id: milestone.id, name: "Go live", date: "2026-01-01", verified: true },
      milestone.gantt_attributes
    )
  end

  test "a verified milestone rejects changes to its name or date" do
    project = Project.create!(name: "Demo")
    milestone = project.milestones.create!(name: "Go live", date: Date.new(2026, 1, 1), verified: true)

    assert_not milestone.update(name: "Renamed")
    assert_includes milestone.errors[:base].join, "can't have their name or date changed"

    milestone.reload
    assert_not milestone.update(date: Date.new(2026, 1, 5))
    assert_includes milestone.errors[:base].join, "can't have their name or date changed"
  end

  test "a verified milestone still allows notes changes" do
    project = Project.create!(name: "Demo")
    milestone = project.milestones.create!(name: "Go live", date: Date.new(2026, 1, 1), verified: true)

    assert milestone.update(notes: "reviewed")
    assert_equal "reviewed", milestone.reload.notes
  end

  test "un-verifying a milestone in the same save as a name/date change is allowed" do
    project = Project.create!(name: "Demo")
    milestone = project.milestones.create!(name: "Go live", date: Date.new(2026, 1, 1), verified: true)

    assert milestone.update(verified: false, name: "Renamed")
    assert_equal "Renamed", milestone.reload.name
    assert_not milestone.verified?
  end

  test "status is date-based (a milestone has no duration)" do
    project = Project.create!(name: "Demo")
    upcoming = project.milestones.create!(name: "Later", date: Date.current + 5)
    today = project.milestones.create!(name: "Now", date: Date.current)
    overdue = project.milestones.create!(name: "Late", date: Date.current - 5)

    assert_equal :upcoming, upcoming.status
    assert_equal :in_progress, today.status
    assert_equal :overdue, overdue.status
  end

  test "verified does not change status — it's a separate signal from date-based status" do
    project = Project.create!(name: "Demo")
    milestone = project.milestones.create!(name: "Old but confirmed", date: Date.current - 100, verified: true)

    assert_equal :overdue, milestone.status
    assert milestone.verified?
  end
end
