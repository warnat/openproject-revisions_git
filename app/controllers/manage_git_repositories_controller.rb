class ManageGitRepositoriesController < ApplicationController
  unloadable

  #To make the project menu visible, you have to initialize the controller's instance variable @project, otherwise it will hide the left menu when called
  before_filter :find_project_by_project_id, :only => [:index]
  
  #Verifies that the user has the permissions for "manage_git_repositories", only for 'index' as it is the only action that renders a view
  before_filter :authorize, :only => :index

  before_filter :require_login
  #Next lines are needed as the view "repository_deployment_credentials/new" is rendered from this controler,
  #the @variables in the view should be accessible from here.
  before_filter :find_repository
  before_filter :set_my_keys
  before_filter :find_credentials
  before_filter :find_post_receive_urls
  before_filter :find_mirrors
  before_filter :find_git_config_keys
  
  #To highlight the menu option when selected
  menu_item :manage_git_repositories, only: [:index]

  def index

    render layout: false if request.xhr?
  end


  private

  def set_my_keys
    @user = User.current
    @gitolite_deploy_keys = @user.gitolite_public_keys.deploy_key.order('title ASC, created_at ASC')
    
    @disabled_deployment_keys = @repository.repository_deployment_credentials.map(&:gitolite_public_key)
    
    @other_deployment_keys = []
    # Admin can use other's deploy keys as well
    @other_deployment_keys = other_deployment_keys if User.current.admin?

  end

  def find_repository
    @repository = @project.repository
    if @repository.nil?
      render_404
    end
  end
  
  def find_credentials
    @repository_deployment_credentials = @repository.repository_deployment_credentials.all
  end
  
  def other_deployment_keys
    users_allowed_to_create_deployment_keys.map { |user| user.gitolite_public_keys.deploy_key.order('title ASC') }.flatten
  end

  def users_allowed_to_create_deployment_keys
    @project.users.select { |user| user != User.current && user.allowed_to?(:create_repository_deployment_credentials, @project) }
  end

  def find_post_receive_urls
    @repository_post_receive_urls = @repository.repository_post_receive_urls.all
  end
  
  def find_mirrors
    @repository_mirrors = @repository.repository_mirrors.all
  end
  
  def find_git_config_keys
    @repository_git_config_keys = @repository.repository_git_config_keys.all
  end
end
