OpenProject::Application.routes.draw do
  # User's own public key management
  scope '/my' do
    resources :public_keys, controller: 'my_public_keys', except: [:edit, :show, :update]
  end

  resources :public_keys, controller: 'gitolite_public_keys', except: [:edit, :show, :update]

  # Gitolite repository management
  scope 'projects/:project_id' do
    resources :manage_git_repository, controller: 'manage_git_repositories', only: :index

    resources :repository_deployment_credentials, controller: 'repository_deployment_credentials'
    resources :repository_post_receive_urls, controller: 'repository_post_receive_urls'
    get 'repository_mirrors/push', :to => 'repository_mirrors#push'
    resources :repository_mirrors, controller: 'repository_mirrors'
    resources :repository_git_config_keys, controller: 'repository_git_config_keys'
  end
  
  # Gitolite hooks
  get 'settings/plugin/:id/install_gitolite_hooks', to: 'settings#install_gitolite_hooks', as: 'install_gitolite_hooks'
  post 'githooks/post-receive/:type/:projectid' => 'gitolite_hooks#post_receive'
end
