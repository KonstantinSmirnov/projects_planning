class MilestonesController < ApplicationController
  before_action :set_project
  before_action :set_milestone, only: [ :show, :update, :destroy ]

  def create
    @milestone = @project.milestones.new(milestone_params)

    if @milestone.save
      redirect_to root_path
    else
      redirect_to root_path, alert: @milestone.errors.full_messages.to_sentence
    end
  end

  def show
  end

  # See TasksController#update for why this can't redirect for JSON
  # requests, and why it responds with gantt_attributes.
  def update
    if @milestone.update(milestone_params)
      respond_to do |format|
        format.html { redirect_to root_path }
        format.json { render json: @milestone.gantt_attributes }
      end
    else
      respond_to do |format|
        format.html { redirect_to root_path, alert: @milestone.errors.full_messages.to_sentence }
        format.json { render json: { errors: @milestone.errors.full_messages }, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @milestone.destroy
    redirect_to root_path
  end

  def reorder
    Array(params[:ids]).each_with_index do |id, index|
      @project.milestones.where(id: id).update_all(position: index)
    end
    head :ok
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_milestone
    @milestone = @project.milestones.find(params[:id])
  end

  def milestone_params
    params.require(:milestone).permit(:name, :date, :notes, :verified)
  end
end
