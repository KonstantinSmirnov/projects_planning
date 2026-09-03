class DataTransfersController < ApplicationController
  # Bumped whenever the payload gains a field. Older files are still accepted —
  # anything they don't carry simply falls back to its default on import.
  FORMAT_VERSION = 2

  def export
    payload = {
      format_version: FORMAT_VERSION,
      exported_at: Time.current,
      teams: Team.ordered.map { |t| t.attributes.slice("name", "color") },
      sprints: Sprint.ordered.map { |s| s.attributes.slice("number", "start_date", "end_date", "release") },
      # Ordered by `position`, and carrying `notes`, so a restore reproduces
      # exactly what was on screen — including any manual drag-and-drop order.
      projects: Project.order(:position, :created_at).includes(:milestones, tasks: :team).map do |project|
        {
          name: project.name,
          description: project.description,
          milestones: project.milestones.map { |m| m.attributes.slice("name", "date", "notes", "verified") },
          tasks: project.tasks.map do |task|
            task.attributes.slice("name", "start_date", "end_date", "notes", "verified")
              # Teams are referenced by name, not id: ids are meaningless across
              # a wipe-and-restore, names are what the user actually recognises.
              .merge("team" => task.team&.name)
          end
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

    counts = { projects: 0, milestones: 0, tasks: 0, sprints: 0, teams: 0 }

    # A full restore destroys and recreates every record — logging each one
    # individually would bury whatever a human actually changed under
    # hundreds of "created"/"deleted" entries. Suppressed in favor of the one
    # summary entry logged below.
    #
    # `suppress` has to wrap the transaction, not sit inside it: Trackable's
    # logging runs from after_*_commit callbacks, which Rails defers until
    # the outermost transaction actually commits — by which point a
    # suppress block placed only around the create!/destroy_all calls would
    # already have exited and reset the flag.
    Activity.suppress do
      ActiveRecord::Base.transaction do
        Project.destroy_all
        Sprint.destroy_all
        Team.destroy_all

        teams_by_name = {}
        Array(data["teams"]).each do |t|
          team = Team.create!(name: t["name"], color: t["color"])
          teams_by_name[team.name] = team
          counts[:teams] += 1
        end

        Array(data["sprints"]).each do |s|
          Sprint.create!(number: s["number"], start_date: s["start_date"], end_date: s["end_date"],
                         release: truthy(s["release"]))
          counts[:sprints] += 1
        end

        Array(data["projects"]).each do |p|
          project = Project.create!(name: p["name"], description: p["description"])
          counts[:projects] += 1

          Array(p["milestones"]).each do |m|
            project.milestones.create!(name: m["name"], date: m["date"], notes: m["notes"],
                                       verified: truthy(m["verified"]))
            counts[:milestones] += 1
          end

          Array(p["tasks"]).each do |t|
            # A file from before teams existed simply has no "team" key, and a
            # file naming a team that isn't in its own teams list still restores
            # the task — unassigned rather than not at all.
            project.tasks.create!(name: t["name"], start_date: t["start_date"], end_date: t["end_date"],
                                  notes: t["notes"], verified: truthy(t["verified"]),
                                  team: teams_by_name[t["team"]])
            counts[:tasks] += 1
          end
        end

        # An import of a pre-teams file would otherwise leave the app with no
        # teams at all and no obvious way back to the defaults.
        Team.ensure_seeded!
      end
    end

    Activity.create!(
      trackable_type: "Import", trackable_id: 0, trackable_name: "Data import", action: "imported",
      details: "Replaced all data: #{counts[:projects]} projects, #{counts[:milestones]} milestones, " \
               "#{counts[:tasks]} tasks, #{counts[:sprints]} sprints, #{counts[:teams]} teams"
    )

    redirect_to root_path, notice: "Imported #{counts[:projects]} projects, #{counts[:milestones]} milestones, " \
                                   "#{counts[:tasks]} tasks, #{counts[:sprints]} sprints and #{counts[:teams]} teams."
  rescue JSON::ParserError
    redirect_to root_path, alert: "That file isn't valid JSON."
  rescue ActiveRecord::RecordInvalid, TypeError, NoMethodError => e
    redirect_to root_path, alert: "Import failed, nothing was changed: #{e.message}"
  end

  private

  # Verified/release arrive as real booleans from our own export, but be
  # forgiving about a hand-edited file using "true"/"1".
  def truthy(value)
    ActiveModel::Type::Boolean.new.cast(value) || false
  end
end
