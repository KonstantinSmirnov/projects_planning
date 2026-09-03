class SprintsController < ApplicationController
  def index
    @sprints = Sprint.ordered.to_a
    @first_number = @sprints.first&.number
    @last_number = @sprints.last&.number
    @current_sprint_number = Sprint.for_date&.number
  end

  def create
    Sprint.add_next!
    redirect_to sprints_path
  end

  def show
    @sprint = find_sprint
    @progress_percent = progress_percent_for(@sprint)
    @project_rows = grouped_items_for(@sprint)
  end

  # One Save button covers every row: each row's fields post here keyed by
  # its own (pre-edit) sprint number, so this applies them all in a single
  # transaction rather than one request per row.
  def update_all
    original_first_number = Sprint.minimum(:number)
    new_first_number = params.dig(:sprints, original_first_number.to_s, :number)

    Sprint.transaction do
      params.fetch(:sprints, {}).each do |number, attrs|
        Sprint.find_by!(number: number).update!(attrs.permit(:start_date, :end_date, :release))
      end

      # Only the first sprint's row carries a number field, and changing it
      # renumbers the whole sequence from there.
      Sprint.renumber_from!(new_first_number) if new_first_number.present?
    end

    redirect_to sprints_path
  rescue ActiveRecord::RecordInvalid => e
    redirect_to sprints_path, alert: e.record.errors.full_messages.to_sentence
  rescue ArgumentError => e
    redirect_to sprints_path, alert: e.message
  end

  def destroy
    sprint = find_sprint

    if sprint.deletable?
      sprint.destroy
      redirect_to sprints_path
    else
      redirect_to sprints_path, alert: "Only the first or last sprint can be deleted."
    end
  end

  private

  def find_sprint
    Sprint.find_by!(number: params[:number])
  end

  def progress_percent_for(sprint)
    today = Date.current
    return 0 if today < sprint.start_date
    return 100 if today > sprint.end_date

    elapsed_days = (today - sprint.start_date).to_i + 1
    sprint_length = (sprint.end_date - sprint.start_date).to_i + 1
    ((elapsed_days / sprint_length.to_f) * 100).round
  end

  def grouped_items_for(sprint)
    Project.includes(:milestones, :tasks).order(:created_at).filter_map do |project|
      milestones = project.milestones.where(date: sprint.start_date..sprint.end_date)
      tasks = project.tasks.where("start_date <= ? AND end_date >= ?", sprint.end_date, sprint.start_date)
      next if milestones.none? && tasks.none?

      { project: project, milestones: milestones, tasks: tasks }
    end
  end
end
