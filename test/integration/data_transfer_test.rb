require "test_helper"

class DataTransferTest < ActionDispatch::IntegrationTest
  setup do
    Project.destroy_all
    Sprint.delete_all
    Team.delete_all

    @team = Team.create!(name: "Launchpad", color: "#f97316")

    Sprint.create!(number: 1, start_date: Date.new(2026, 1, 6), end_date: Date.new(2026, 1, 19), release: true)

    @second = Project.create!(name: "Second", description: "b")
    @first = Project.create!(name: "First", description: "a")
    # Deliberately out of creation order, as a drag-and-drop reorder leaves it.
    @second.update!(position: 2)
    @first.update!(position: 1)

    @first.milestones.create!(name: "Go Live", date: Date.new(2026, 3, 1), notes: "milestone notes", verified: true)
    @first.tasks.create!(name: "Build", start_date: Date.new(2026, 1, 5), end_date: Date.new(2026, 2, 1),
                         notes: "task notes", team: @team, verified: true)
  end

  test "export keeps notes and manual ordering" do
    get export_data_path
    assert_response :success

    payload = JSON.parse(response.body)
    assert_equal [ "First", "Second" ], payload["projects"].map { |p| p["name"] }
    assert_equal "milestone notes", payload["projects"].first["milestones"].first["notes"]
    assert_equal "task notes", payload["projects"].first["tasks"].first["notes"]
  end

  # Regression: teams, team assignment, the verified flag and a sprint's
  # release flag were all added after the exporter was written, and silently
  # weren't in the file — so restoring a backup quietly dropped every one of
  # them.
  test "export carries teams, team assignment, verified and release" do
    get export_data_path
    payload = JSON.parse(response.body)

    assert_equal [ { "name" => "Launchpad", "color" => "#f97316" } ], payload["teams"]
    assert_equal true, payload["sprints"].first["release"]

    task = payload["projects"].first["tasks"].first
    assert_equal "Launchpad", task["team"]
    assert_equal true, task["verified"]
    assert_equal true, payload["projects"].first["milestones"].first["verified"]
  end

  test "a full export/import round trip restores everything" do
    get export_data_path
    backup = response.body

    Project.destroy_all
    Sprint.destroy_all

    post data_import_path, params: { confirmed: "1", file: json_upload(backup) }
    assert_redirected_to root_path

    assert_equal [ "First", "Second" ], Project.order(:position).pluck(:name)
    assert_equal "milestone notes", Milestone.first.notes
    assert_equal "task notes", Task.first.notes
    assert_equal 1, Sprint.count

    assert_equal [ "Launchpad" ], Team.pluck(:name)
    assert_equal "#f97316", Team.first.color
    assert_equal "Launchpad", Task.first.team&.name
    assert Task.first.verified?, "the task's verified flag must survive a restore"
    assert Milestone.first.verified?, "the milestone's verified flag must survive a restore"
    assert Sprint.first.release?, "the sprint's release flag must survive a restore"
  end

  # A file written before teams existed must still import cleanly rather than
  # blowing up on the missing key — and must not leave the app team-less.
  test "an older export without teams still imports" do
    legacy = {
      "projects" => [ { "name" => "Legacy", "description" => nil,
                        "milestones" => [ { "name" => "M", "date" => "2026-05-01" } ],
                        "tasks" => [ { "name" => "T", "start_date" => "2026-05-01", "end_date" => "2026-05-10" } ] } ],
      "sprints" => [ { "number" => 1, "start_date" => "2026-01-06", "end_date" => "2026-01-19" } ]
    }.to_json

    post data_import_path, params: { confirmed: "1", file: json_upload(legacy) }
    assert_redirected_to root_path

    assert_equal [ "Legacy" ], Project.pluck(:name)
    assert_nil Task.first.team
    assert_not Task.first.verified?
    assert_not Sprint.first.release?
    assert_equal Team::DEFAULTS.map { |t| t[:name] }.sort, Team.pluck(:name).sort
  end

  # A task naming a team the file doesn't define must still come back, just
  # unassigned — losing the whole task would be far worse.
  test "a task naming an unknown team imports unassigned" do
    payload = { "teams" => [], "sprints" => [],
                "projects" => [ { "name" => "P", "tasks" => [ { "name" => "T", "start_date" => "2026-05-01",
                                                                "end_date" => "2026-05-10", "team" => "Ghost" } ] } ] }.to_json

    post data_import_path, params: { confirmed: "1", file: json_upload(payload) }
    assert_redirected_to root_path
    assert_equal "T", Task.first.name
    assert_nil Task.first.team
  end

  test "import refuses a file that isn't an export and changes nothing" do
    post data_import_path, params: { confirmed: "1", file: json_upload("[1, 2, 3]") }
    assert_redirected_to root_path
    assert_equal 2, Project.count
    assert_equal 1, Sprint.count
    assert_equal 1, Team.count
  end

  test "import without the confirmation checkbox changes nothing" do
    get export_data_path
    post data_import_path, params: { file: json_upload(response.body) }
    assert_equal 2, Project.count
  end

  private

  def json_upload(body)
    file = Tempfile.new([ "export", ".json" ])
    file.write(body)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "application/json")
  end
end
