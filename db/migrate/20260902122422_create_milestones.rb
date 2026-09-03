class CreateMilestones < ActiveRecord::Migration[8.1]
  def change
    create_table :milestones do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.date :date, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
