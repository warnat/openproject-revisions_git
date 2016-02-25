class RepositoryDeploymentCredentialsController < ApplicationController #RevisionsGitControllerBase
  unloadable


  before_filter :find_project
  #before_filter :find_project_by_project_id
  before_filter :find_repository
  before_filter :set_my_keys
  before_filter :find_credentials
  before_filter :find_deployment_credential, only: [:edit, :update, :destroy]
  before_filter :find_key,                   only: [:edit, :update, :destroy]

  def index
#    @repository_deployment_credentials = @repository.repository_deployment_credentials.all
#    render layout: false
  end


  def show
#    @repository_deployment_credentials = @repository.repository_deployment_credentials.all
#    render layout: false
#    render_404
  end


  def new
    @credential = RepositoryDeploymentCredential.new(repository_deployment_credentials_allowed_params)
  end


  def create
    @credential = RepositoryDeploymentCredential.new(repository_deployment_credentials_allowed_params)
    
    key = GitolitePublicKey.find_by_id(params[:repository_deployment_credential][:gitolite_public_key_id])

    # If admin, let credential be owned by owner of key...
    if User.current.admin?
      @credential.user = key.user if !key.nil?
    else
      @credential.user = User.current
    end

    save_and_flash
    redirect_to controller: 'manage_git_repositories', action: 'index'
  end

  
  def edit
    
  end

  
  def update
    if @credential.active?
      @credential.active = 0
    else
      @credential.active = 1
    end
    
    save_and_flash
    redirect_to controller: 'manage_git_repositories', action: 'index'
  end

  
  def destroy
    will_delete_key = @key.deploy_key? && @key.delete_when_unused && @key.repository_deployment_credentials.count == 1
    @credential.destroy
    if will_delete_key && @key.repository_deployment_credentials.empty?
      # Key no longer used -- delete it!
      @key.destroy
      flash[:notice] = 'Deployment credential and Deployment key deleted'
    else
      flash[:notice] = 'Deployment credential deleted'
    end

    redirect_to controller: 'manage_git_repositories', action: 'index'
  end



  private

  def set_my_keys
    @user = User.current
    @gitolite_deploy_keys = @user.gitolite_public_keys.deploy_key.order('title ASC, created_at ASC')
  end

    

  def find_project
    #To make the project menu visible, you have to initialize the controller's instance variable @project.
    # @project variable must be set before calling the authorize filter
    @project = Project.find(params[:project_id])
  end

  def find_repository
    @repository = @project.repository
    if @repository.nil?
      render_404
    end
  end

  
  def repository_deployment_credentials_allowed_params
    params.require(:repository_deployment_credential).permit(:repository_id, :gitolite_public_key_id, :user_id, :active, :perm)
  end

  def save_and_flash
    if @credential.save
      flash[:notice] = 'Repository credential saved'
    else
      flash[:error] = @credential.errors.full_messages.to_sentence
    end
  end

  def find_credentials
    @repository_deployment_credentials = @repository.repository_deployment_credentials.all
  end

  
  def find_key
    key = @credential.gitolite_public_key
    if key && key.user && (User.current.admin? || key.user == User.current)
      @key = key
    elsif key
      render_403
    else
      render_404
    end
  end
  
  def find_deployment_credential
    begin
      credential = @repository.repository_deployment_credentials.find(params[:credential])
    rescue ActiveRecord::RecordNotFound => e
      render_404
    else
      if credential.user && (User.current.admin? || credential.user == User.current)
        @credential = credential
      else
        render_403
      end
    end
  end


end
