Rails.application.routes.draw do
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'

  devise_for :users

  resources :books, only: :index do
    member do
      get :list_copy
      post :list_copy, to: 'books#post_list_copy'
      get :reserve_copy
      post :reserve_copy, to: 'books#post_reserve_copy'
    end
  end

  root to: 'home#index'
end
