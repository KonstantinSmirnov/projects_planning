class CreateSprintsAndDropSprintAnchors < ActiveRecord::Migration[8.1]
  SPRINT_LENGTH_DAYS = 14
  SEED_THROUGH = Date.new(2027, 12, 31)

  def up
    create_table :sprints do |t|
      t.integer :number, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.timestamps
    end
    add_index :sprints, :number, unique: true

    anchors = execute("SELECT sprint_number, start_date FROM sprint_anchors ORDER BY sprint_number ASC").to_a

    if anchors.any?
      number = anchors.first["sprint_number"].to_i
      loop do
        governing = anchors.select { |a| a["sprint_number"].to_i <= number }.max_by { |a| a["sprint_number"].to_i }
        start_date = Date.parse(governing["start_date"].to_s) + ((number - governing["sprint_number"].to_i) * SPRINT_LENGTH_DAYS)
        end_date = start_date + (SPRINT_LENGTH_DAYS - 1)

        execute <<~SQL
          INSERT INTO sprints (number, start_date, end_date, created_at, updated_at)
          VALUES (#{number}, '#{start_date}', '#{end_date}', NOW(), NOW())
        SQL

        break if start_date > SEED_THROUGH

        number += 1
      end
    end

    drop_table :sprint_anchors
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
