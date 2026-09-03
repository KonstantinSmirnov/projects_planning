class TeamsController < ApplicationController
  def index
    @teams = Team.ordered
  end

  def create
    Team.create!(name: "New team", color: "#6b7280")
    redirect_to root_path
  rescue ActiveRecord::RecordInvalid => e
    redirect_to root_path, alert: e.record.errors.full_messages.to_sentence
  end

  # One Save button covers every row: each row's fields post here keyed by
  # its own team id, applied in a single transaction. Unlike Sprints
  # configuration (TASK-031), this redirects `_top` — closing the overlay on
  # save is the wanted behavior for Teams (TASK-038 rework).
  def update_all
    Team.transaction do
      params.fetch(:teams, {}).each do |id, attrs|
        Team.find(id).update!(attrs.permit(:name, :color))
      end
    end

    redirect_to root_path
  rescue ActiveRecord::RecordInvalid => e
    redirect_to root_path, alert: e.record.errors.full_messages.to_sentence
  end

  def destroy
    Team.find(params[:id]).destroy
    redirect_to root_path
  end
end
