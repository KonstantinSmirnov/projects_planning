Sprint.generate_from!(Date.new(2026, 1, 5)) if Sprint.none?

website_relaunch = Project.find_or_create_by!(name: "Website Relaunch") do |project|
  project.description = "Rebuild the marketing site on the new design system."
end

website_relaunch.tasks.find_or_create_by!(name: "Development") do |task|
  task.start_date = Date.new(2026, 1, 5)
  task.end_date = Date.new(2026, 2, 27)
end

website_relaunch.tasks.find_or_create_by!(name: "UAT") do |task|
  task.start_date = Date.new(2026, 3, 2)
  task.end_date = Date.new(2026, 3, 20)
end

website_relaunch.milestones.find_or_create_by!(name: "Go Live") do |milestone|
  milestone.date = Date.new(2026, 3, 27)
end

mobile_app = Project.find_or_create_by!(name: "Mobile App v2") do |project|
  project.description = "Add offline support and push notifications."
end

mobile_app.milestones.find_or_create_by!(name: "Kickoff") do |milestone|
  milestone.date = Date.new(2026, 1, 19)
end

mobile_app.tasks.find_or_create_by!(name: "Development") do |task|
  task.start_date = Date.new(2026, 1, 19)
  task.end_date = Date.new(2026, 4, 10)
end

mobile_app.tasks.find_or_create_by!(name: "UAT") do |task|
  task.start_date = Date.new(2026, 4, 13)
  task.end_date = Date.new(2026, 4, 24)
end

mobile_app.milestones.find_or_create_by!(name: "Go Live") do |milestone|
  milestone.date = Date.new(2026, 5, 1)
end
