require "test_helper"

class ProjectStatusOverlayTest < ActionDispatch::IntegrationTest
  setup do
    @project = Project.create!(name: "Report Demo", description: "Some notes")
  end

  test "the project overlay renders every milestone and task with its computed status" do
    @project.milestones.create!(name: "Kickoff", date: Date.current - 10, verified: true)
    @project.milestones.create!(name: "Beta review", date: Date.current + 5)
    @project.tasks.create!(name: "Design", start_date: Date.current - 20, end_date: Date.current - 10, verified: true)
    team = Team.create!(name: "QA", color: "#f97316")
    @project.tasks.create!(name: "Build", start_date: Date.current - 5, end_date: Date.current + 5, team: team)
    @project.tasks.create!(name: "Overdue thing", start_date: Date.current - 30, end_date: Date.current - 15)

    get project_path(@project)

    assert_response :success
    assert_select "td", text: /Kickoff/
    assert_select "td", text: /Beta review/
    assert_select "td", text: /Design/
    assert_select "td", text: /Build/
    assert_select "td", text: "QA"
    assert_select "td", text: /Overdue thing/

    assert_select "span", text: "In progress: 1"
    assert_select "span", text: "Overdue: 3"
    assert_select "span", text: "Upcoming: 1"
  end

  test "the project overlay marks verified items with a checkmark without changing their date-based status" do
    kickoff = @project.milestones.create!(name: "Kickoff", date: Date.current - 10, verified: true)
    @project.milestones.create!(name: "Beta review", date: Date.current + 5)

    get project_path(@project)

    assert_response :success
    assert_select "span[title=?]", "Verified", count: 1
    assert_select "td", text: "Overdue" # Kickoff stays overdue despite being verified
    assert kickoff.verified?
  end

  test "the project overlay renders cleanly with no milestones or tasks at all" do
    get project_path(@project)

    assert_response :success
    assert_select "p", text: "Nothing added yet."
  end

  test "the project overlay keeps the name, description, and date range, with no separate report page" do
    @project.milestones.create!(name: "Kickoff", date: Date.current)

    get project_path(@project)

    assert_response :success
    assert_select "input[value=?]", @project.name
    assert_select "textarea", text: @project.description
    assert_select "[data-controller=gantt]", false
  end
end
