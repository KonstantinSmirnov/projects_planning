class AddNotesToMilestonesAndTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :milestones, :notes, :text
    add_column :tasks, :notes, :text
  end
end
