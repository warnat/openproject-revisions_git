class ManageGitRepositoriesController < ApplicationController
  unloadable

  include GitolitePublicKeysHelper

  #To make the project menu visible, you have to initialize the controller's instance variable @project, otherwise it will hide the left menu when called
  before_filter :find_project_by_project_id, :only => [:index]
  
  #Verifies that the user has the permissions for "manage_git_repositories", only for 'index' as it is the only action that renders a view
  before_filter :authorize, :only => :index

  #To highlight the menu option when selected
  menu_item :manage_git_repositories, only: [:index]

  def index
    #Seems not to be necessary
    render layout: false if request.xhr?
  end
end