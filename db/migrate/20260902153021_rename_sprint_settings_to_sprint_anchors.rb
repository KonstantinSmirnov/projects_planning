class RenameSprintSettingsToSprintAnchors < ActiveRecord::Migration[8.1]
  def change
    rename_table :sprint_settings, :sprint_anchors
    rename_column :sprint_anchors, :anchor_number, :sprint_number
    rename_column :sprint_anchors, :anchor_start_date, :start_date
    add_index :sprint_anchors, :sprint_number, unique: true
  end
end
