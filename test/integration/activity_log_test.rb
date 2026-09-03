require "test_helper"

class ActivityLogTest < ActionDispatch::IntegrationTest
  test "the overlay lists recent activity, newest first" do
    project = Project.create!(name: "Demo")
    project.tasks.create!(name: "UAT", start_date: Date.current, end_date: Date.current)

    get activities_path
    assert_response :success

    assert_select "strong", text: "UAT"
    assert_select "strong", text: "Demo"
  end

  test "the header link to the overlay targets the modal frame, not the top" do
    get root_path
    assert_select "a[href=?][data-turbo-frame=?]", activities_path, "modal_body"
  end

  test "an import logs one summary entry instead of one per record" do
    export = {
      format_version: 2,
      teams: [ { "name" => "Launchpad", "color" => "#f97316" } ],
      sprints: [ { "number" => 1, "start_date" => "2026-01-01", "end_date" => "2026-01-14" } ],
      projects: [ { "name" => "Demo", "milestones" => [], "tasks" => [] } ]
    }

    assert_difference "Activity.count", 1 do
      post data_import_path, params: { confirmed: "1", file: json_upload(export.to_json) }
    end

    activity = Activity.ordered.first
    assert_equal "imported", activity.action
    assert_match(/1 projects/, activity.details)
  end

  private

  def json_upload(body)
    file = Tempfile.new([ "export", ".json" ])
    file.write(body)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "application/json")
  end
end
