require "test_helper"

class DataTransferTest < ActionDispatch::IntegrationTest
  setup do
    Project.destroy_all
    Sprint.delete_all

    Sprint.create!(number: 1, start_date: Date.new(2026, 1, 6), end_date: Date.new(2026, 1, 19))

    @second = Project.create!(name: "Second", description: "b")
    @first = Project.create!(name: "First", description: "a")
    # Deliberately out of creation order, as a drag-and-drop reorder leaves it.
    @second.update!(position: 2)
    @first.update!(position: 1)

    @first.milestones.create!(name: "Go Live", date: Date.new(2026, 3, 1), notes: "milestone notes")
    @first.tasks.create!(name: "Build", start_date: Date.new(2026, 1, 5), end_date: Date.new(2026, 2, 1), notes: "task notes")
  end

  test "export keeps notes and manual ordering" do
    get export_data_path
    assert_response :success

    payload = JSON.parse(response.body)
    assert_equal [ "First", "Second" ], payload["projects"].map { |p| p["name"] }
    assert_equal "milestone notes", payload["projects"].first["milestones"].first["notes"]
    assert_equal "task notes", payload["projects"].first["tasks"].first["notes"]
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
  end

  test "import refuses a file that isn't an export and changes nothing" do
    post data_import_path, params: { confirmed: "1", file: json_upload("[1, 2, 3]") }
    assert_redirected_to root_path
    assert_equal 2, Project.count
    assert_equal 1, Sprint.count
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
