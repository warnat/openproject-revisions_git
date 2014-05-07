module OpenProject::GitHosting::GitoliteWrapper
  class Admin

  	attr_reader :admin

  	def initialize(action, object_id, options)
  		@admin = GitoliteWrapper.cached_gitolite_admin

      @object_id      = object_id
      @action         = action
      @options        = options
  	end

  	def logger
  		Rails.logger
  	end

  end
 end