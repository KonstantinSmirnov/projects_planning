class ActivitiesController < ApplicationController
  RECENT_LIMIT = 200

  def index
    @activities = Activity.ordered.limit(RECENT_LIMIT)
  end
end
