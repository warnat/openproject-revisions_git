module OpenProject::GitHosting::GitoliteWrapper
  class Admin

    attr_reader :admin

    def initialize(action, object_id, options={})
      @admin = OpenProject::GitHosting::GitoliteWrapper.admin
      @gitolite_config = @admin.config

      @object_id      = object_id
      @action         = action
      @options        = options
    end

    def logger
      Rails.logger
    end


    def gitolite_admin_repo_commit(message = '')
      logger.info("#{@action} : commiting to Gitolite...")
      @admin.save("#{@action} : #{message}")
    rescue => e
      logger.error { "#{e.message}" }
    end

    def run
      send(@action)
    end
    handle_asynchronously :run
  end
 end