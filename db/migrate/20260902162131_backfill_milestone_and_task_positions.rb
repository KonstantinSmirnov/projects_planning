class BackfillMilestoneAndTaskPositions < ActiveRecord::Migration[8.1]
  def up
    Project.find_each do |project|
      project.milestones.order(:date, :id).each_with_index do |milestone, index|
        milestone.update_column(:position, index)
      end

      project.tasks.order(:start_date, :id).each_with_index do |task, index|
        task.update_column(:position, index)
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
