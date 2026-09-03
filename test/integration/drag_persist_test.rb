require "test_helper"

# Covers the bug behind TASK-018's second rework: dragging a bar persists its
# new dates via a raw `fetch` PATCH with `Accept: application/json`. A 301/302
# redirect response to that request would have the browser re-issue the same
# non-GET method (PATCH) against the redirect target per the Fetch spec —
# hitting "PATCH /", which has no route, and reporting a 404 back to the
# client even though the underlying update already succeeded. These requests
# must get a direct JSON response instead of a redirect.
class DragPersistTest < ActionDispatch::IntegrationTest
  setup do
    @project = Project.create!(name: "Demo")
  end

  test "a JSON PATCH to update a task's dates responds directly, without a redirect" do
    task = @project.tasks.create!(name: "UAT", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 5))

    patch project_task_path(@project, task),
      params: { task: { start_date: "2026-01-10", end_date: "2026-01-15" } }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json" }

    assert_response :success
    assert_nil response.headers["Location"], "must respond directly, not redirect"
    assert_equal Date.new(2026, 1, 10), task.reload.start_date
    assert_equal Date.new(2026, 1, 15), task.end_date

    # TASK-051: the client (both persistItemDates and item_form_controller)
    # syncs its in-memory copy from this body, so its shape matters as much
    # as the redirect behavior.
    body = response.parsed_body
    assert_equal task.id, body["id"]
    assert_equal "2026-01-10", body["start_date"]
    assert_equal "2026-01-15", body["end_date"]
  end

  test "a JSON PATCH to update a milestone's date responds directly, without a redirect" do
    milestone = @project.milestones.create!(name: "Go live", date: Date.new(2026, 1, 1))

    patch project_milestone_path(@project, milestone),
      params: { milestone: { date: "2026-01-20" } }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json" }

    assert_response :success
    assert_equal Date.new(2026, 1, 20), milestone.reload.date
    assert_equal "2026-01-20", response.parsed_body["date"]
  end

  test "a JSON PATCH response reflects a newly-assigned team's derived name and color" do
    team = Team.create!(name: "Launchpad", color: "#f97316")
    task = @project.tasks.create!(name: "UAT", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 5))

    patch project_task_path(@project, task),
      params: { task: { team_id: team.id } }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json" }

    assert_response :success
    body = response.parsed_body
    assert_equal team.id, body["team_id"]
    assert_equal "Launchpad", body["team_name"]
    assert_equal "#f97316", body["team_color"]
  end

  test "a JSON PATCH attempting to drag a verified task is rejected" do
    task = @project.tasks.create!(name: "UAT", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 5), verified: true)

    patch project_task_path(@project, task),
      params: { task: { start_date: "2026-01-10", end_date: "2026-01-15" } }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json" }

    assert_response :unprocessable_content
    assert_match(/can't have their name or dates changed/, response.parsed_body["errors"].join)
    assert_equal Date.new(2026, 1, 1), task.reload.start_date, "the date must be untouched"
  end

  test "an invalid JSON PATCH reports errors directly, without a redirect" do
    task = @project.tasks.create!(name: "UAT", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 5))

    patch project_task_path(@project, task),
      params: { task: { start_date: "2026-01-15", end_date: "2026-01-10" } }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json" }

    assert_response :unprocessable_content
    assert_match(/must be on or after/, response.parsed_body["errors"].join)
  end

  test "a normal HTML form submission still redirects, closing the overlay" do
    task = @project.tasks.create!(name: "UAT", start_date: Date.new(2026, 1, 1), end_date: Date.new(2026, 1, 5))

    patch project_task_path(@project, task), params: { task: { start_date: "2026-01-10", end_date: "2026-01-15" } }

    assert_redirected_to root_path
    assert_equal Date.new(2026, 1, 10), task.reload.start_date
  end
end
