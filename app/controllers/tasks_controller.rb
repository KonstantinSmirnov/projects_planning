class TasksController < ApplicationController
  before_action :set_project
  before_action :set_task, only: [ :show, :update, :destroy ]

  def create
    @task = @project.tasks.new(task_params)

    if @task.save
      redirect_to root_path
    else
      redirect_to root_path, alert: @task.errors.full_messages.to_sentence
    end
  end

  def show
    @sprints = Sprint.ordered
    @teams = Team.ordered
  end

  # Both dragging a bar (a raw `fetch` PATCH) and the detail overlay's own
  # "Save" button (via `item-form_controller.js`, TASK-051) update in place
  # with `Accept: application/json` — that path must not redirect: per the
  # Fetch spec, a 301/302 redirect preserves a non-GET method like PATCH on
  # the follow-up request, so `fetch` would re-issue "PATCH /" (no such
  # route) and get back a 404, even though this update already succeeded.
  # Responds with the task's current `gantt_attributes` so the client can
  # sync its in-memory copy from the same source of truth the initial page
  # load used, rather than re-deriving team_name/team_color itself. A plain
  # (non-fetch) HTML form submission — not currently used by anything, but
  # kept working rather than assumed away — still gets the normal redirect.
  def update
    if @task.update(task_params)
      respond_to do |format|
        format.html { redirect_to root_path }
        format.json { render json: @task.gantt_attributes }
      end
    else
      respond_to do |format|
        format.html { redirect_to root_path, alert: @task.errors.full_messages.to_sentence }
        format.json { render json: { errors: @task.errors.full_messages }, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @task.destroy
    redirect_to root_path
  end

  def reorder
    Array(params[:ids]).each_with_index do |id, index|
      @project.tasks.where(id: id).update_all(position: index)
    end
    head :ok
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_task
    @task = @project.tasks.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:name, :start_date, :end_date, :notes, :team_id, :verified)
  end
end
