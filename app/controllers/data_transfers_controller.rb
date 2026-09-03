class DataTransfersController < ApplicationController
  def export
    payload = {
      exported_at: Time.current,
      sprints: Sprint.ordered.map { |s| s.attributes.slice("number", "start_date", "end_date") },
      # Ordered by `position`, and carrying `notes`, so a restore reproduces
      # exactly what was on screen — including any manual drag-and-drop order.
      projects: Project.order(:position, :created_at).includes(:milestones, :tasks).map do |project|
        {
          name: project.name,
          description: project.description,
          milestones: project.milestones.map { |m| m.attributes.slice("name", "date", "notes") },
          tasks: project.tasks.map { |t| t.attributes.slice("name", "start_date", "end_date", "notes") }
        }
      end
    }

    send_data JSON.pretty_generate(payload.as_json),
      filename: "projects-planning-export-#{Date.current.iso8601}.json",
      type: "application/json"
  end

  def new_import
  end

  def import
    unless params[:confirmed] == "1"
      return redirect_to root_path, alert: "Import was not confirmed."
    end

    file = params[:file]
    return redirect_to root_path, alert: "Choose a file to import." if file.blank?

    data = JSON.parse(file.read)
    unless data.is_a?(Hash) && (data.key?("projects") || data.key?("sprints"))
      return redirect_to root_path, alert: "That file doesn't look like a Projects Planning export."
    end

    counts = { projects: 0, milestones: 0, tasks: 0, sprints: 0 }

    ActiveRecord::Base.transaction do
      Project.destroy_all
      Sprint.destroy_all

      Array(data["sprints"]).each do |s|
        Sprint.create!(number: s["number"], start_date: s["start_date"], end_date: s["end_date"])
        counts[:sprints] += 1
      end

      Array(data["projects"]).each do |p|
        project = Project.create!(name: p["name"], description: p["description"])
        counts[:projects] += 1

        Array(p["milestones"]).each do |m|
          project.milestones.create!(name: m["name"], date: m["date"], notes: m["notes"])
          counts[:milestones] += 1
        end

        Array(p["tasks"]).each do |t|
          project.tasks.create!(name: t["name"], start_date: t["start_date"], end_date: t["end_date"], notes: t["notes"])
          counts[:tasks] += 1
        end
      end
    end

    redirect_to root_path, notice: "Imported #{counts[:projects]} projects, #{counts[:milestones]} milestones, " \
                                   "#{counts[:tasks]} tasks and #{counts[:sprints]} sprints."
  rescue JSON::ParserError
    redirect_to root_path, alert: "That file isn't valid JSON."
  rescue ActiveRecord::RecordInvalid, TypeError, NoMethodError => e
    redirect_to root_path, alert: "Import failed, nothing was changed: #{e.message}"
  end
end
