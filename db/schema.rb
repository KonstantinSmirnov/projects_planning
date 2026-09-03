# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_03_181938) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "activities", force: :cascade do |t|
    t.string "action", null: false
    t.string "actor"
    t.datetime "created_at", null: false
    t.text "details"
    t.string "project_name"
    t.bigint "trackable_id", null: false
    t.string "trackable_name", null: false
    t.string "trackable_type", null: false
    t.index ["created_at"], name: "index_activities_on_created_at"
  end

  create_table "milestones", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "position", default: 0, null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false, null: false
    t.index ["project_id"], name: "index_milestones_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "sprints", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.integer "number", null: false
    t.boolean "release", default: false, null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.index ["number"], name: "index_sprints_on_number", unique: true
  end

  create_table "tasks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "position", default: 0, null: false
    t.bigint "project_id", null: false
    t.date "start_date", null: false
    t.bigint "team_id"
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false, null: false
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["team_id"], name: "index_tasks_on_team_id"
  end

  create_table "teams", force: :cascade do |t|
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_teams_on_name", unique: true
  end

  add_foreign_key "milestones", "projects"
  add_foreign_key "tasks", "projects"
  add_foreign_key "tasks", "teams", on_delete: :nullify
end
