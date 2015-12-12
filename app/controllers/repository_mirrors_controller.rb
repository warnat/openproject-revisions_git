class RepositoryMirrorsController < ApplicationController
  unloadable

  before_filter :find_project
  before_filter :find_repository
  before_filter :find_mirror, only: [:edit, :update, :destroy]

  def index
#    @repository_mirrors = @repository.repository_mirrors.all
#    render layout: false
  end


  def show
#    @repository_mirrors = @repository.repository_mirrors.all
#    render layout: false
#    render_404
  end


  def new
    @mirror = RepositoryMirror.new(repository_mirrors_allowed_params)
  end


  def create
    @mirror = RepositoryMirror.new(repository_mirrors_allowed_params)

    save_and_flash
    redirect_to controller: 'manage_git_repositories', action: 'index'
  end

  
  def edit
    
  end

  
  def destroy
    if @mirror.destroy
      flash[:notice] = 'Mirror deleted'
      redirect_to controller: 'manage_git_repositories', action: 'index'
    end
  end

  
  def push
    #flash[:notice] = 'Repository mirror saved'
    redirect_to controller: 'manage_git_repositories', action: 'index'
  end


  private

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

    def repository_mirrors_allowed_params
      params.require(:repository_mirror).permit(:repository_id, :active, :url, :push_mode, :include_all_branches, :include_all_tags, :explicit_refspec)
    end
  
    def save_and_flash
      if @mirror.save
        flash[:notice] = 'Repository mirror saved'
      else
        flash[:error] = @mirror.errors.full_messages.to_sentence
      end
    end

  def find_mirror
    begin
      mirror = @repository.repository_mirrors.find(params[:mirror])
    rescue ActiveRecord::RecordNotFound => e
      render_404
    else
      if User.current.admin? || User.current.allowed_to?(:create_repository_mirrors, @project)
        @mirror = mirror
      else
          render_403
      end
    end
  end

end
