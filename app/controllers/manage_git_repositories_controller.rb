class ManageGitRepositoriesController < ApplicationController
  unloadable

  include GitolitePublicKeysHelper

  #To make the page part of the projects menu, otherwise it will hide the left menu when called
  #default_search_scope :manage_git_repositories
  before_filter :find_project_by_project_id, :only => [:index]
  

  #To highlight the menu option when selected
  menu_item :manage_git_repositories, only: [:index]

  def index
    #Seems not to be necessary
    render layout: false if request.xhr?
  end
end