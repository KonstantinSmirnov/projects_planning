require "test_helper"

class ActivityTest < ActiveSupport::TestCase
  test "creating a task logs a created activity" do
    project = Project.create!(name: "Demo")

    assert_difference "Activity.count", 1 do
      project.tasks.create!(name: "UAT", start_date: Date.current, end_date: Date.current + 1)
    end

    activity = Activity.ordered.first
    assert_equal "Task", activity.trackable_type
    assert_equal "UAT", activity.trackable_name
    assert_equal "created", activity.action
    assert_equal "Demo", activity.project_name
    assert_nil activity.details
  end

  test "updating a task logs the before/after of each changed field" do
    project = Project.create!(name: "Demo")
    task = project.tasks.create!(name: "UAT", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 5))

    assert_difference "Activity.count", 1 do
      task.update!(name: "UAT v2")
    end

    activity = Activity.ordered.first
    assert_equal "updated", activity.action
    assert_equal "Name: UAT → UAT v2", activity.details
  end

  test "updating a task's team logs team names, not raw ids" do
    project = Project.create!(name: "Demo")
    task = project.tasks.create!(name: "UAT", start_date: Date.current, end_date: Date.current)
    team = Team.create!(name: "Launchpad", color: "#f97316")

    task.update!(team: team)

    assert_equal "Team: — → Launchpad", Activity.ordered.first.details
  end

  test "a save with no actual changes logs nothing" do
    project = Project.create!(name: "Demo")
    task = project.tasks.create!(name: "UAT", start_date: Date.current, end_date: Date.current)

    assert_no_difference "Activity.count" do
      task.update!(name: "UAT")
    end
  end

  test "destroying a milestone logs a deleted activity" do
    project = Project.create!(name: "Demo")
    milestone = project.milestones.create!(name: "Go live", date: Date.current)

    assert_difference "Activity.count", 1 do
      milestone.destroy!
    end

    activity = Activity.ordered.first
    assert_equal "Milestone", activity.trackable_type
    assert_equal "deleted", activity.action
  end

  test "destroying a project cascades to logging its milestones and tasks too" do
    project = Project.create!(name: "Demo")
    project.milestones.create!(name: "Go live", date: Date.current)
    project.tasks.create!(name: "UAT", start_date: Date.current, end_date: Date.current)

    assert_difference "Activity.count", 3 do
      project.destroy!
    end

    types = Activity.ordered.limit(3).pluck(:trackable_type, :action)
    assert_includes types, [ "Project", "deleted" ]
    assert_includes types, [ "Milestone", "deleted" ]
    assert_includes types, [ "Task", "deleted" ]
  end

  test "a sprint's activity label includes its number, not a generic name" do
    sprint = Sprint.create!(number: 9001, start_date: Date.current, end_date: Date.current + 13)

    assert_equal "Sprint 9001", Activity.ordered.first.trackable_name
  ensure
    sprint&.destroy
  end

  test "Activity.suppress prevents logging for the duration of the block" do
    project = Project.create!(name: "Demo")

    assert_no_difference "Activity.count" do
      Activity.suppress do
        project.tasks.create!(name: "UAT", start_date: Date.current, end_date: Date.current)
      end
    end
  end

  test "reordering via update_all does not log anything" do
    project = Project.create!(name: "Demo")
    task_a = project.tasks.create!(name: "A", start_date: Date.current, end_date: Date.current)
    task_b = project.tasks.create!(name: "B", start_date: Date.current, end_date: Date.current)

    assert_no_difference "Activity.count" do
      project.tasks.where(id: task_b.id).update_all(position: 0)
      project.tasks.where(id: task_a.id).update_all(position: 1)
    end
  end
end
