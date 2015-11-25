class RepositoryDeploymentCredentialsController < ApplicationController #RevisionsGitControllerBase
  unloadable


  before_filter :find_project
  before_filter :find_repository
  before_filter :set_my_keys
  before_filter :find_credentials

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
    
    save_and_flash
    redirect_to controller: 'manage_git_repositories', action: 'index'
end

  def edit
    
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

  
end
