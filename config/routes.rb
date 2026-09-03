Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :projects, except: [ :edit ] do
    collection { patch :reorder }
    member do
      get :new_item
    end
    resources :milestones, except: [ :index, :new, :edit ] do
      collection { patch :reorder }
    end
    resources :tasks, except: [ :index, :new, :edit ] do
      collection { patch :reorder }
    end
  end

  get "sprints", to: "sprints#index", as: :sprints
  post "sprints", to: "sprints#create"
  patch "sprints", to: "sprints#update_all"
  get "sprints/:number", to: "sprints#show", as: :sprint, constraints: { number: /\d+/ }
  delete "sprints/:number", to: "sprints#destroy", constraints: { number: /\d+/ }

  get "public_holidays", to: "public_holidays#index", as: :public_holidays

  get "activities", to: "activities#index", as: :activities

  get "teams", to: "teams#index", as: :teams
  post "teams", to: "teams#create"
  patch "teams", to: "teams#update_all"
  delete "teams/:id", to: "teams#destroy", as: :team, constraints: { id: /\d+/ }

  get "designsystem", to: "design_system#index", as: :design_system

  get "data/export", to: "data_transfers#export", as: :export_data
  get "data/import", to: "data_transfers#new_import", as: :new_data_import
  post "data/import", to: "data_transfers#import", as: :data_import

  # Defines the root path route ("/")
  root "projects#index"
end
