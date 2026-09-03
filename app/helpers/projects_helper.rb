module ProjectsHelper
  def gantt_projects_payload(projects)
    projects.map do |project|
      {
        id: project.id,
        name: project.name,
        start_date: project.start_date&.iso8601,
        end_date: project.end_date&.iso8601,
        milestones: project.milestones.map(&:gantt_attributes),
        tasks: project.tasks.map(&:gantt_attributes)
      }
    end.to_json
  end

  def gantt_teams_payload(teams)
    teams.map { |t| { id: t.id, name: t.name, color: t.color } }.to_json
  end

  def gantt_sprints_payload(sprints)
    sprints.map do |s|
      {
        number: s.number, start_date: s.start_date.iso8601, end_date: s.end_date.iso8601,
        release: s.release,
        code_freeze_date: s.release? ? s.code_freeze_date.iso8601 : nil,
        submit_to_store_date: s.release? ? s.submit_to_store_date.iso8601 : nil,
        publish_date: s.release? ? s.publish_date.iso8601 : nil
      }
    end.to_json
  end

  def gantt_holidays_payload
    holidays = PublicHoliday.all_for(*PublicHoliday.default_range)
    holidays.map do |h|
      { date: h.date.iso8601, name: h.name, region: h.region, region_label: h.region_label, color_class: h.region_color }
    end.to_json
  end
end
