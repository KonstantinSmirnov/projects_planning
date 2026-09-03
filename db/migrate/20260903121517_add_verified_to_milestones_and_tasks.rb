class AddVerifiedToMilestonesAndTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :milestones, :verified, :boolean, null: false, default: false
    add_column :tasks, :verified, :boolean, null: false, default: false
  end
end
