class AddPositionToProjects < ActiveRecord::Migration[8.1]
  def up
    add_column :projects, :position, :integer, null: false, default: 0

    Project.order(:created_at).each_with_index do |project, index|
      project.update_column(:position, index)
    end
  end

  def down
    remove_column :projects, :position
  end
end
