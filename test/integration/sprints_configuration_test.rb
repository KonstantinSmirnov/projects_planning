require "test_helper"

class SprintsConfigurationTest < ActionDispatch::IntegrationTest
  setup do
    Sprint.delete_all
    @sprint = Sprint.create!(number: 1, start_date: Date.new(2026, 1, 6), end_date: Date.new(2026, 1, 19))
    Sprint.create!(number: 2, start_date: Date.new(2026, 1, 20), end_date: Date.new(2026, 2, 2))
  end

  # Regression (TASK-031): one Save button at the bottom saves every row —
  # each row's inputs live outside the save `<form>` and reference it by the
  # HTML `form` attribute instead, so the per-row Delete button (itself a
  # `<form>`) is never nested inside another form, which browsers mangle.
  test "every sprint's fields are associated with the shared save form, not nested inside it" do
    get sprints_path
    assert_response :success

    assert_select "form#sprints_save_form" do
      # Only the hidden CSRF/method fields form_with renders automatically —
      # every real field lives outside this form, associated by `form=`.
      assert_select "input[type=date], input[type=checkbox], input[type=submit]", false,
        "the save form must carry no real fields of its own — they live outside it"
    end

    Sprint.ordered.each do |sprint|
      assert_select "input[name=?][form=?]", "sprints[#{sprint.number}][start_date]", "sprints_save_form"
      assert_select "input[name=?][form=?]", "sprints[#{sprint.number}][end_date]", "sprints_save_form"
      assert_select "input[type=checkbox][name=?][form=?]", "sprints[#{sprint.number}][release]", "sprints_save_form"
    end

    assert_select "input[type=submit][value=?][form=?]", "Save changes", "sprints_save_form"
    assert_select "form[action=?] input[type=submit]", sprint_path(@sprint.number), false,
      "there must be no per-row Save button anymore"
  end

  # Regression (TASK-028): these used to force a top-level navigation
  # (`data-turbo-frame="_top"`), which tore down the overlay on every save.
  # Leaving the frame targeting unset lets Turbo default to the enclosing
  # "modal_body" frame, so a save/add/delete just refreshes the overlay.
  test "sprint operations stay scoped to the enclosing frame, not the top" do
    get sprints_path
    assert_select "[data-turbo-frame=?]", "_top", false, "no sprint form/button should escape the overlay via _top"
  end

  test "an invalid renumber shows its error inline, redirected back to the overlay" do
    patch sprints_path, params: { sprints: { "1" => { number: "0", start_date: "2026-01-06", end_date: "2026-01-19" } } }
    follow_redirect!
    assert_select "p", text: /Sprint number must be 1 or greater/
  end

  test "saving updates every changed row in one request" do
    patch sprints_path, params: {
      sprints: {
        "1" => { start_date: "2026-01-13", end_date: "2026-01-26", release: "1" },
        "2" => { start_date: "2026-01-27", end_date: "2026-02-09", release: "0" }
      }
    }
    assert_redirected_to sprints_path

    first, second = Sprint.ordered.to_a
    assert_equal Date.new(2026, 1, 13), first.start_date
    assert_equal Date.new(2026, 1, 26), first.end_date
    assert first.release?
    assert_equal Date.new(2026, 1, 27), second.start_date
    assert_not second.release?
  end

  test "only the first sprint shows a number field" do
    get sprints_path
    assert_select "input[name=?]", "sprints[#{Sprint.ordered.first.number}][number]"
    assert_select "input[name=?]", "sprints[#{Sprint.ordered.last.number}][number]", count: 0
  end

  test "changing the first sprint's number renumbers the rest incrementally" do
    Sprint.create!(number: 3, start_date: Date.new(2026, 2, 3), end_date: Date.new(2026, 2, 16))

    patch sprints_path, params: { sprints: { "1" => { number: "25", start_date: "2026-01-06", end_date: "2026-01-19" } } }
    assert_redirected_to sprints_path
    assert_equal [ 25, 26, 27 ], Sprint.ordered.pluck(:number)
    # Dates must be untouched by the renumbering itself.
    assert_equal Date.new(2026, 2, 3), Sprint.find_by(number: 27).start_date
  end

  test "renumbering downwards through the existing range doesn't trip the unique index" do
    Sprint.delete_all
    (5..8).each_with_index do |number, index|
      Sprint.create!(number: number, start_date: Date.new(2026, 1, 6) + (index * 14),
                     end_date: Date.new(2026, 1, 19) + (index * 14))
    end

    patch sprints_path, params: { sprints: { "5" => { number: "6", start_date: "2026-01-06", end_date: "2026-01-19" } } }
    assert_equal [ 6, 7, 8, 9 ], Sprint.ordered.pluck(:number)
  end

  test "a number below one is rejected and nothing changes" do
    patch sprints_path, params: { sprints: { "1" => { number: "0", start_date: "2026-01-06", end_date: "2026-01-19" } } }
    assert_redirected_to sprints_path
    assert_equal [ 1, 2 ], Sprint.ordered.pluck(:number)
  end

  test "renumbering keeps add_next! continuing the sequence" do
    patch sprints_path, params: { sprints: { "1" => { number: "40", start_date: "2026-01-06", end_date: "2026-01-19" } } }
    Sprint.add_next!
    assert_equal [ 40, 41, 42 ], Sprint.ordered.pluck(:number)
  end

  test "only the first and last sprint can be deleted" do
    Sprint.create!(number: 3, start_date: Date.new(2026, 2, 3), end_date: Date.new(2026, 2, 16))

    delete sprint_path(2)
    assert_equal 3, Sprint.count, "a middle sprint must not be deletable"

    delete sprint_path(3)
    assert_equal 2, Sprint.count
  end
end
