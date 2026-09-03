class CreateActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :activities do |t|
      # No FK — the record this describes may already be gone by the time
      # anyone reads the log (e.g. a deleted task), and `trackable_name`
      # below is what keeps the entry readable at that point anyway.
      t.string :trackable_type, null: false
      t.bigint :trackable_id, null: false
      t.string :trackable_name, null: false
      # Which project this belongs to, if any (a task/milestone's own
      # project, or the project itself) — nil for Team/Sprint, which aren't
      # scoped to one. Snapshot for the same reason as trackable_name.
      t.string :project_name
      t.string :action, null: false
      t.text :details
      # No User model yet — left null until one exists, so this column is
      # ready to populate rather than needing a later migration.
      t.string :actor

      t.datetime :created_at, null: false
    end

    add_index :activities, :created_at
  end
end
