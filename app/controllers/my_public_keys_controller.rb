class MyGitolitePublicKeysController < ApplicationController
  unloadable

  layout 'my'
  menu_item :public_keys

  before_filter :require_login
  before_filter :set_user

  before_filter :set_users_keys, :only => [:index]
  before_filter :find_gitolite_public_key, :only => [:destroy]

  helper :gitolite_public_keys


  def create
    @gitolite_public_key = GitolitePublicKey.new(gitolite_keys_allowed_params)
    if @gitolite_public_key.save
      flash[:notice] = l(:notice_public_key_created, :title => view_context.keylabel(@gitolite_public_key).html_safe)
    else
      flash[:error] = @gitolite_public_key.errors.full_messages.to_sentence
    end
    redirect_to url_for(:action => 'index')
  end

  def destroy
    if request.delete?
      if @gitolite_public_key.destroy
        flash[:notice] = l(:notice_public_key_deleted, :title => view_context.keylabel(@gitolite_public_key))
      end
      redirect_to url_for(:action => 'index')

    end
  end


  private

  def gitolite_keys_allowed_params
    params.require(:gitolite_public_key).permit(:title, :key, :key_type)
  end


end
