Rails.application.routes.draw do
  devise_for :users
  resources :books, only: %i[index show]

  root to: 'home#index'
end
