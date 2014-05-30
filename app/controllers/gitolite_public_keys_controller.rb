class GitolitePublicKeysController < ApplicationController
  unloadable

  before_filter :require_admin
  before_filter :set_user
  before_filter :set_redirect_url

  before_filter :set_users_keys, :only => [:index]
  before_filter :find_gitolite_public_key, :only => [:destroy]

  helper :gitolite_public_keys

  def create
    byebug
    @gitolite_public_key = GitolitePublicKey.new(gitolite_keys_allowed_params)
    if @gitolite_public_key.save
      flash[:notice] = l(:notice_public_key_created, :title => view_context.keylabel(@gitolite_public_key).html_safe)
    else
      flash[:error] = @gitolite_public_key.errors.full_messages.to_sentence
    end
    redirect_to @redirect_url
  end


  def destroy
    if @gitolite_public_key.destroy
      flash[:notice] = l(:notice_public_key_deleted, :title => view_context.keylabel(@gitolite_public_key))
    end
    redirect_to @redirect_url
  end


  private

  def set_user
    @user = User.find_by_id(gitolite_keys_allowed_params[:user_id])
  end

  def gitolite_keys_allowed_params
    params.require(:gitolite_public_key).permit(:user_id, :title, :key, :key_type)
  end

  def set_redirect_url
    @redirect_url = url_for(:controller => 'users', :action => 'edit', :id => gitolite_keys_allowed_params[:user_id], :tab => 'keys')
  end
end
