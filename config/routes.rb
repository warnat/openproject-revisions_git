OpenProject::Application.routes.draw do
  # User's own public key management
  scope '/my' do
    resources :public_keys, controller: 'my_public_keys', except: [:edit, :show, :update]
  end

  namespace 'admin' do
    resources :public_keys, controller: 'gitolite_public_keys', except: [:edit, :show, :update]
  end
  
  #The route will be "projects/:project_id/manage_git_repository"
  scope 'projects/:project_id' do
    resources :manage_git_repository, controller: 'manage_git_repositories', only: :index
  end

end
