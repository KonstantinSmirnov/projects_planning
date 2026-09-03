class CreateSprintSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :sprint_settings do |t|
      t.integer :anchor_number, null: false, default: 1
      t.date :anchor_start_date, null: false

      t.timestamps
    end
  end
end
