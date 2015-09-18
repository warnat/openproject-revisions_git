class RepositoryGitConfigKeysController < RevisionsGitControllerBase
  before_filter :set_current_tab
  before_filter :can_view_config_keys,   only: [:index]
  before_filter :can_create_config_keys, only: [:new, :create]
  before_filter :can_edit_config_keys,   only: [:edit, :update, :destroy]
  before_filter :create_config_key,      only: [:create]

  before_filter :find_repository_git_config_key, except: [:index, :new, :create]

  def index
    @repository_git_config_keys = RepositoryGitConfigKey.find_all_by_repository_id(@repository.id)

    respond_to do |format|
      format.html { render layout: 'popup' }
      format.js
    end
  end

  def new
    @git_config_key = RepositoryGitConfigKey.new
  end

  def create
    if @git_config_key.save
      flash[:notice] = l(:notice_git_config_key_created)
      key_change_success
    else
      fail_key_change(:notice_git_config_key_create_failed, 'create')
    end
  end

  def update
    if @git_config_key.update_attributes(params[:repository_git_config_keys])
      flash[:notice] = l(:notice_git_config_key_updated)
      key_change_success
    else
      fail_key_change(:notice_git_config_key_update_failed, 'edit')
    end
  end

  def destroy
    respond_to do |format|
      if @git_config_key.destroy
        flash[:notice] = l(:notice_git_config_key_deleted)
        format.js { render js: 'window.location = #{success_url.to_json};' }
      else
        format.js { render layout: false }
      end
    end
  end

  private

  def fail_unless_allowed_to(permission)
    render_403 unless view_context.user_allowed_to(permission, @project)
  end

  def can_view_config_keys
    fail_unless_allowed_to(:view_repository_git_config_keys)
  end

  def can_create_config_keys
    fail_unless_allowed_to(:create_repository_git_config_keys)
  end

  def can_edit_config_keys
    fail_unless_allowed_to(:edit_repository_git_config_keys)
  end

  def find_repository_git_config_key
    git_config_key = RepositoryGitConfigKey.find_by_id(params[:id])

    if git_config_key && git_config_key.repository_id == @repository.id
      @git_config_key = git_config_key
    elsif git_config_key
      render_403
    else
      render_404
    end
  end

  def set_current_tab
    @tab = 'repository_git_config_keys'
  end

  def create_config_key
    @git_config_key = RepositoryGitConfigKey.new(params[:repository_git_config_keys])
    @git_config_key.repository = @repository
  end

  def key_change_success
    respond_to do |format|
      format.html { redirect_to success_url }
      format.js   { render js: "window.location = #{success_url.to_json};" }
    end
  end

  def fail_key_change(action, label)
    respond_to do |format|
      format.html {
        flash[:error] = l(label)
        render action: action
      }
      format.js { render 'form_error', layout: false }
    end
  end
end
