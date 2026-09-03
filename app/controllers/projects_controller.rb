class ProjectsController < ApplicationController
  before_action :set_project, only: [ :show, :update, :destroy, :new_item ]

  def index
    Sprint.ensure_seeded!
    Team.ensure_seeded!
    @projects = Project.order(:position).includes(:milestones, tasks: :team)
    @sprints = Sprint.ordered
    @teams = Team.ordered
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      redirect_to root_path
    else
      redirect_to root_path, alert: @project.errors.full_messages.to_sentence
    end
  end

  def show
    @milestones = @project.milestones.order(:date)
    @tasks = @project.tasks.includes(:team).order(:start_date)
  end

  def update
    if @project.update(project_params)
      redirect_to root_path
    else
      redirect_to root_path, alert: @project.errors.full_messages.to_sentence
    end
  end

  def destroy
    @project.destroy
    redirect_to root_path
  end

  def new_item
    current_sprint = Sprint.for_date
    @milestone = @project.milestones.new(date: Date.current)
    @task = @project.tasks.new(start_date: current_sprint&.start_date, end_date: current_sprint&.end_date)
    @sprints = Sprint.ordered
    @teams = Team.ordered
  end

  def reorder
    Array(params[:ids]).each_with_index do |id, index|
      Project.where(id: id).update_all(position: index)
    end
    head :ok
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :description)
  end
end
