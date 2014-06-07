require 'fileutils'

module OpenProject::GitHosting
  module Patches
    module SettingPatch

      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods

          before_save  :save_git_hosting_values
          after_commit :restore_git_hosting_values
        end
      end

      module InstanceMethods

        private

        @@old_valuehash = ((Setting.plugin_openproject_git_hosting).clone rescue {})
        @@resync_projects = false
        @@resync_ssh_keys = false
        @@delete_trash_repo = []

        def save_git_hosting_values
          # Only validate settings for our plugin
          if self.name == 'plugin_openproject_git_hosting'
            valuehash = self.value

            if valuehash[:gitolite_scripts_dir] && (valuehash[:gitolite_scripts_dir] != @@old_valuehash[:gitolite_scripts_dir])

              # Remove old bin directory and scripts, since about to change directory
              FileUtils.rm_rf(OpenProject::GitHosting::GitoliteWrapper.get_scripts_dir_path)

              # Script directory either absolute or relative to redmine root
              stripped = valuehash[:gitolite_scripts_dir].lstrip.rstrip

              # Get rid of extra path components
              normalizedFile = File.expand_path(stripped, "/")

              if (normalizedFile == "/")
                # Assume that we are relative bin directory ("/" and "" => "")
                valuehash[:gitolite_scripts_dir] = "./"
              elsif (stripped[0,1] != "/")
                # Clobber leading '/' add trailing '/'
                valuehash[:gitolite_scripts_dir] = normalizedFile[1..-1] + "/"
              else
                # Add trailing '/'
                valuehash[:gitolite_scripts_dir] = normalizedFile + "/"
              end
            end

            # Server domain should not include any path components. Also, ports should be numeric.
            [ :ssh_server_domain, :http_server_domain ].each do |setting|
              if valuehash[setting]
                if valuehash[setting] != ''
                  normalizedServer = valuehash[setting].lstrip.rstrip.split('/').first
                  if (!normalizedServer.match(/^[a-zA-Z0-9\-]+(\.[a-zA-Z0-9\-]+)*(:\d+)?$/))
                    valuehash[setting] = @@old_valuehash[setting]
                  else
                    valuehash[setting] = normalizedServer
                  end
                else
                  valuehash[setting] = @@old_valuehash[setting]
                end
              end
            end


            # HTTPS server should not include any path components. Also, ports should be numeric.
            if valuehash[:https_server_domain]
              if valuehash[:https_server_domain] != ''
                normalizedServer = valuehash[:https_server_domain].lstrip.rstrip.split('/').first
                if (!normalizedServer.match(/^[a-zA-Z0-9\-]+(\.[a-zA-Z0-9\-]+)*(:\d+)?$/))
                  valuehash[:https_server_domain] = @@old_valuehash[:https_server_domain]
                else
                  valuehash[:https_server_domain] = normalizedServer
                end
              end
            end


            # Normalize http repository subdirectory path, should be either empty or relative and end in '/'
            if valuehash[:http_server_subdir]
              normalizedFile  = File.expand_path(valuehash[:http_server_subdir].lstrip.rstrip, "/")
              if (normalizedFile != "/")
                # Clobber leading '/' add trailing '/'
                valuehash[:http_server_subdir] = normalizedFile[1..-1] + "/"
              else
                valuehash[:http_server_subdir] = ''
              end
            end

            # Normalize paths, should be relative and end in '/'
            [ :gitolite_global_storage_dir, :gitolite_recycle_bin_dir ].each do |setting|
              if valuehash[setting]
                normalizedFile  = File.expand_path(valuehash[setting].lstrip.rstrip, "/")
                if (normalizedFile != "/")
                  # Clobber leading '/' add trailing '/'
                  valuehash[setting] = normalizedFile[1..-1] + "/"
                else
                  valuehash[setting] = @@old_valuehash[setting]
                end
              end
            end


            # Normalize Redmine Subdirectory path, should be either empty or relative and end in '/'
            if valuehash[:gitolite_storage_subdir]
              normalizedFile  = File.expand_path(valuehash[:gitolite_storage_subdir].lstrip.rstrip, "/")
              if (normalizedFile != "/")
                # Clobber leading '/' add trailing '/'
                valuehash[:gitolite_storage_subdir] = normalizedFile[1..-1] + "/"
              else
                valuehash[:gitolite_storage_subdir] = ''
              end
            end


            # Exclude bad expire times (and exclude non-numbers)
            if valuehash[:gitolite_recycle_bin_expiration_time]
              if valuehash[:gitolite_recycle_bin_expiration_time].to_f > 0
                valuehash[:gitolite_recycle_bin_expiration_time] = "#{(valuehash[:gitolite_recycle_bin_expiration_time].to_f * 10).to_i / 10.0}"
              else
                valuehash[:gitolite_recycle_bin_expiration_time] = @@old_valuehash[:gitolite_recycle_bin_expiration_time]
              end
            end


            # Validate ssh port > 0 and < 65537 (and exclude non-numbers)
            if valuehash[:gitolite_server_port]
              if valuehash[:gitolite_server_port].to_i > 0 and valuehash[:gitolite_server_port].to_i < 65537
                valuehash[:gitolite_server_port] = "#{valuehash[:gitolite_server_port].to_i}"
              else
                valuehash[:gitolite_server_port] = @@old_valuehash[:gitolite_server_port]
              end
            end


            # Validate git author address
            if valuehash[:git_config_email].blank?
              valuehash[:git_config_email] = Setting.mail_from.to_s.strip.downcase
            else
              if !/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i.match(valuehash[:git_config_email])
                valuehash[:git_config_email] = @@old_valuehash[:git_config_email]
              end
            end


            # Validate gitolite_timeout > 0 and < 30 (and exclude non-numbers)
            if valuehash[:gitolite_timeout]
              if valuehash[:gitolite_timeout].to_i > 0 and valuehash[:gitolite_timeout].to_i < 30
                valuehash[:gitolite_timeout] = "#{valuehash[:gitolite_timeout].to_i}"
              else
                valuehash[:gitolite_timeout] = @@old_valuehash[:gitolite_timeout]
              end
            end


            ## This a force update
            if valuehash[:gitolite_resync_all_projects] == 'true'
              @@resync_projects = true
              valuehash[:gitolite_resync_all_projects] = false
            end


            ## This a force update
            if valuehash[:gitolite_resync_all_ssh_keys] == 'true'
              @@resync_ssh_keys = true
              valuehash[:gitolite_resync_all_ssh_keys] = false
            end


            if valuehash.has_key?(:gitolite_purge_repos) && !valuehash[:gitolite_purge_repos].empty?
              @@delete_trash_repo = valuehash[:gitolite_purge_repos]
              valuehash[:gitolite_purge_repos] = []
            end


            if valuehash[:all_projects_use_git] == 'false'
              valuehash[:init_repositories_on_create] = 'false'
            end


            # Save back results
            self.value = valuehash
          end
        end


        def restore_git_hosting_values
          # Only perform after-actions on settings for our plugin
          if self.name == 'plugin_openproject_git_hosting'
            valuehash = self.value

            # Settings cache doesn't seem to invalidate symbolic versions of Settings immediately,
            # so, any use of Setting.plugin_openproject_git_hosting[] by things called during this
            # callback will be outdated.... True for at least some versions of redmine plugin...
            #
            # John Kubiatowicz 12/21/2011
            if Setting.respond_to?(:check_cache)
              # Clear out all cached settings.
              Setting.check_cache
            end


            ## SSH infos has changed, update scripts!
            if @@old_valuehash[:gitolite_scripts_dir] != valuehash[:gitolite_scripts_dir] ||
               @@old_valuehash[:gitolite_user] != valuehash[:gitolite_user] ||
               @@old_valuehash[:gitolite_ssh_private_key] != valuehash[:gitolite_ssh_private_key] ||
               @@old_valuehash[:gitolite_ssh_public_key] != valuehash[:gitolite_ssh_public_key] ||
               @@old_valuehash[:gitolite_server_port] != valuehash[:gitolite_server_port]
                # Need to update scripts
                # TODO?
                #OpenProject::GitHosting::GitoliteWrapper.update_scripts
            end


            ## Storage infos has changed, move repositories!
            if @@old_valuehash[:gitolite_global_storage_dir] != valuehash[:gitolite_global_storage_dir] ||
               @@old_valuehash[:gitolite_storage_subdir] != valuehash[:gitolite_storage_subdir] ||
               @@old_valuehash[:hierarchical_organisation] != valuehash[:hierarchical_organisation]
                # Need to update everyone!
                projects = Project.active_or_archived.includes(:repositories).all.select { |x| x if x.parent_id.nil? }
                if projects.length > 0
                  OpenProject::GitHosting::GitHosting.logger.info("Gitolite configuration has been modified : repositories hierarchy")
                  OpenProject::GitHosting::GitHosting.logger.info("Resync all projects (root projects : '#{projects.length}')...")
                  OpenProject::GitHosting::GitoliteWrapper.update(:move_repositories_tree, projects.length, {:flush_cache => true})
                end
            end


            ## Gitolite config file has changed, create a new one!
            if @@old_valuehash[:gitolite_config_file] != valuehash[:gitolite_config_file] ||
               @@old_valuehash[:gitolite_config_has_admin_key] != valuehash[:gitolite_config_has_admin_key]
                # Need to update everyone!
                projects = Project.active_or_archived.includes(:repositories).all
                if projects.length > 0
                  OpenProject::GitHosting::GitHosting.logger.info("Gitolite configuration has been modified, resync all projects...")
                  OpenProject::GitHosting::GitoliteWrapper.update(:update_all_projects, projects.length)
                end
            end


            ## Gitolite user has changed, check if this new one has our hooks!
            if @@old_valuehash[:gitolite_user] != valuehash[:gitolite_user]
              # TODO
              hooks = OpenProject::GitHosting::Hooks.new
              hooks.check_install
            end


            ## A resync has been asked within the interface, update all projects in force mode
            if @@resync_projects == true
              # Need to update everyone!
              projects = Project.active_or_archived.includes(:repositories).all
              if projects.length > 0
                OpenProject::GitHosting::GitHosting.logger.info("Forced resync of all projects (#{projects.length})...")
                OpenProject::GitHosting::GitoliteWrapper.update(:update_all_projects, projects.length)
              end

              @@resync_projects = false
            end


            ## A resync has been asked within the interface, update all projects in force mode
            if @@resync_ssh_keys == true
              # Need to update everyone!
              users = User.all
              if users.length > 0
                OpenProject::GitHosting::GitHosting.logger.info("Forced resync of all ssh keys (#{users.length})...")
                OpenProject::GitHosting::GitoliteWrapper.update(:update_all_ssh_keys_forced, users.length)
              end

              @@resync_ssh_keys = false
            end


            ## Gitolite hooks config has changed, update our .gitconfig!
            if @@old_valuehash[:http_server_domain] !=  valuehash[:http_server_domain] ||
               @@old_valuehash[:https_server_domain] !=  valuehash[:https_server_domain] ||
               @@old_valuehash[:gitolite_hooks_debug] != valuehash[:gitolite_hooks_debug] ||
               @@old_valuehash[:gitolite_force_hooks_update] != valuehash[:gitolite_force_hooks_update] ||
               @@old_valuehash[:gitolite_hooks_are_asynchronous] != valuehash[:gitolite_hooks_are_asynchronous]
                # Need to update our .gitconfig
                # TODO
                hooks = OpenProject::GitHosting::Hooks.new
                hooks.hook_params_installed?
            end


            ## Gitolite cache has changed, clear cache entries!
            if @@old_valuehash[:gitolite_cache_max_time] != valuehash[:gitolite_cache_max_time]
              OpenProject::GitHosting::Cache.clear_obsolete_cache_entries
            end


            if !@@delete_trash_repo.empty?
              OpenProject::GitHosting.update(:purge_recycle_bin, @@delete_trash_repo)
              @@delete_trash_repo = []
            end


            @@old_valuehash = valuehash.clone
          end
        end

      end

    end
  end
end

Setting.send(:include, OpenProject::GitHosting::Patches::SettingPatch)
