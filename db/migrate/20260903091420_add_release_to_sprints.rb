class AddReleaseToSprints < ActiveRecord::Migration[8.1]
  def change
    add_column :sprints, :release, :boolean, null: false, default: false
  end
end
