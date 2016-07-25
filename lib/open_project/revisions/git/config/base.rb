module OpenProject::Revisions::Git
  module Config
    module Base
      extend self

      ###############################
      ##                           ##
      ##  CONFIGURATION ACCESSORS  ##
      ##                           ##
      ###############################


      def get_setting(setting, bool = false)
        if bool
          return_bool do_get_setting(setting)
        else
          return do_get_setting(setting)
        end
      end


      def reload_from_file!
        ## Get default config from init.rb
        default_hash = Redmine::Plugin.find('openproject_revisions_git').settings[:default]
        do_reload_config(default_hash)
      end


      private


        def return_bool(value)
          value == 'true' ? true : false
        end


        def do_get_setting(setting)
          setting = setting.to_sym

          ## Wrap this in a begin/rescue statement because Setting table
          ## may not exist on first migration
          begin
            value = Setting.plugin_openproject_revisions_git[setting]
          rescue => e
            value = Redmine::Plugin.find('openproject_revisions_git').settings[:default][setting]
          else
            ## The Setting table exist but does not contain the value yet, fallback to default
            value = Redmine::Plugin.find('openproject_revisions_git').settings[:default][setting] if value.nil?
          end

          value
        end


        def do_reload_config(default_hash)
          ## Refresh Settings cache
          Setting.check_cache

          ## Get actual values
          valuehash = (Setting.plugin_openproject_revisions_git).clone rescue {}

          ## Update!
          changes = 0

          default_hash.each do |key, value|
            if valuehash[key] != value
              console_logger.info("Changing '#{key}' : #{valuehash[key]} => #{value}")
              valuehash[key] = value
              changes += 1
            end
          end

          if changes == 0
            console_logger.info('No changes necessary.')
          else
            commit_changes(valuehash)
          end
        end


        def commit_changes(valuehash)
          console_logger.info('Committing changes ... ')
          begin
            ## Update Settings
            Setting.plugin_openproject_revisions_git = valuehash
            ## Refresh Settings cache
            Setting.check_cache
            console_logger.info('Success!')
          rescue => e
            console_logger.error('Failure.')
            console_logger.error(e.message)
          end
        end


        def console_logger
          OpenProject::Revisions::Git::ConsoleLogger
        end


        def file_logger
          OpenProject::Revisions::Git.logger
        end

    end
  end
end
