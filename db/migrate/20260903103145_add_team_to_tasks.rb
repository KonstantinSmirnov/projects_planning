class AddTeamToTasks < ActiveRecord::Migration[8.1]
  def change
    add_reference :tasks, :team, null: true, foreign_key: { on_delete: :nullify }
  end
end
