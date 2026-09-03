require "test_helper"

class VerifiedFlagTest < ActionDispatch::IntegrationTest
  setup do
    @project = Project.create!(name: "Demo")
  end

  test "a task defaults to unverified and can be marked verified" do
    task = @project.tasks.create!(name: "UAT", start_date: Date.current, end_date: Date.current + 1)
    assert_not task.verified?

    patch project_task_path(@project, task), params: {
      task: { name: task.name, start_date: task.start_date, end_date: task.end_date, verified: "1" }
    }
    assert task.reload.verified?
  end

  test "a milestone defaults to unverified and can be marked verified" do
    milestone = @project.milestones.create!(name: "Go live", date: Date.current)
    assert_not milestone.verified?

    patch project_milestone_path(@project, milestone), params: {
      milestone: { name: milestone.name, date: milestone.date, verified: "1" }
    }
    assert milestone.reload.verified?
  end

  test "the Gantt payload includes verified for both milestones and tasks" do
    task = @project.tasks.create!(name: "UAT", start_date: Date.current, end_date: Date.current + 1, verified: true)
    milestone = @project.milestones.create!(name: "Go live", date: Date.current, verified: true)

    get root_path
    assert_response :success
    body = CGI.unescapeHTML(response.body)
    assert_match(/"id":#{task.id},"name":"UAT".*?"verified":true/, body)
    assert_match(/"id":#{milestone.id},"name":"Go live".*?"verified":true/, body)
  end
end
