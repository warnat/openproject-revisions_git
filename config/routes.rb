OpenProject::Application.routes.draw do

  # User's own public key management
  scope "/my" do
    resources :public_keys, :controller => 'my_public_keys', :except => [:edit, :show, :update]
  end

  namespace "admin" do
    resources :public_keys, :controller => 'gitolite_public_keys', :except => [:edit, :show, :update]
  end

  # match 'repositories/:repository_id/mirrors/:id/push', :to => 'repository_mirrors#push', :via => [:get], :as => 'push_to_mirror'

  # match 'repositories/:repository_id/download_revision/:rev', :to  => 'download_git_revision#index',
  #                                                             :via => [:get],
  #                                                             :as  => 'download_git_revision'

  # resources :repositories do
  #   constraints(repository_id: /\d+/, id: /\d+/) do
  #     resources :mirrors,                controller: 'repository_mirrors'
  #     resources :post_receive_urls,      controller: 'repository_post_receive_urls'
  #     resources :deployment_credentials, controller: 'repository_deployment_credentials'
  #     resources :git_config_keys,        controller: 'repository_git_config_keys'
  #   end
  # end

  # SMART HTTP
  match 'git/:repo_path/*git_params',
    :repo_path => /([^\/]+\/)*?[^\/]+\.git/, :to => 'smart_http#index'

  # POST RECEIVE
  match 'githooks/post-receive/:type/:projectid',  :to => 'gitolite_hooks#post_receive', :via => [:post]

end
