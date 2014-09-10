require 'fileutils'

module OpenProject::Revisions::Git
  module Patches
    module SettingPatch

      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods

          before_save  :save_revisions_git_values
          after_commit :restore_revisions_git_values
        end
      end

      module InstanceMethods

        private

        @@old_valuehash = ((Setting.plugin_openproject_revisions_git).clone rescue {})
        @@resync_projects = false
        @@resync_ssh_keys = false
        @@delete_trash_repo = []

        def save_revisions_git_values
          # Only validate settings for our plugin
          if self.name == 'plugin_openproject_revisions_git'
            valuehash = self.value

            if valuehash[:gitolite_scripts_dir] && (valuehash[:gitolite_scripts_dir] != @@old_valuehash[:gitolite_scripts_dir])

              # Remove old bin directory and scripts, since about to change directory
              FileUtils.rm_rf(OpenProject::Revisions::Git::GitoliteWrapper.get_scripts_dir_path)

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
            if valuehash[:gitolite_global_storage_dir]
              normalizedFile  = File.expand_path(valuehash[:gitolite_global_storage_dir].lstrip.rstrip, "/")
              if (normalizedFile != "/")
                # Clobber leading '/' add trailing '/'
                valuehash[:gitolite_global_storage_dir] = normalizedFile[1..-1] + "/"
              else
                valuehash[:gitolite_global_storage_dir] = @@old_valuehash[:gitolite_global_storage_dir]
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


            if valuehash[:all_projects_use_git] == 'false'
              valuehash[:init_repositories_on_create] = 'false'
            end


            # Save back results
            self.value = valuehash
          end
        end


        def restore_revisions_git_values
          # Only perform after-actions on settings for our plugin
          if self.name == 'plugin_openproject_revisions_git'
            valuehash = self.value

            ## Storage infos has changed, move repositories!
            if @@old_valuehash[:gitolite_global_storage_dir] != valuehash[:gitolite_global_storage_dir] ||
               @@old_valuehash[:gitolite_storage_subdir] != valuehash[:gitolite_storage_subdir] ||
               @@old_valuehash[:hierarchical_organisation] != valuehash[:hierarchical_organisation]
                # Need to update everyone!
                projects = Project.active.includes(:repositories).all.select { |x| x if x.parent_id.nil? }
                if projects.length > 0
                  OpenProject::Revisions::Git::GitoliteWrapper.logger.info("Gitolite configuration has been modified : repositories hierarchy")
                  OpenProject::Revisions::Git::GitoliteWrapper.logger.info("Resync all projects (root projects : '#{projects.length}')...")
                  OpenProject::Revisions::Git::GitoliteWrapper.update(:move_repositories_tree, projects.length)
                end
            end


            ## Gitolite config file has changed, create a new one!
            if @@old_valuehash[:gitolite_config_file] != valuehash[:gitolite_config_file] ||
               @@old_valuehash[:gitolite_config_has_admin_key] != valuehash[:gitolite_config_has_admin_key]
                # Need to update everyone!
                projects = Project.active.includes(:repositories).all
                if projects.length > 0
                  OpenProject::Revisions::Git::GitoliteWrapper.logger.info("Gitolite configuration has been modified, resync all projects...")
                  OpenProject::Revisions::Git::GitoliteWrapper.update(:update_all_projects, projects.length)
                end
            end


            ## A resync has been asked within the interface, update all projects in force mode
            if @@resync_projects == true
              # Need to update everyone!
              projects = Project.active.includes(:repositories).all
              if projects.length > 0
                OpenProject::Revisions::Git::GitoliteWrapper.logger.info("Forced resync of all projects (#{projects.length})...")
                OpenProject::Revisions::Git::GitoliteWrapper.update(:update_all_projects, projects.length)
              end

              @@resync_projects = false
            end


            ## A resync has been asked within the interface, update all projects in force mode
            if @@resync_ssh_keys == true
              # Need to update everyone!
              users = User.all
              if users.length > 0
                OpenProject::Revisions::Git::GitoliteWrapper.logger.info("Forced resync of all ssh keys (#{users.length})...")
                OpenProject::Revisions::Git::GitoliteWrapper.update(:update_all_ssh_keys_forced, users.length)
              end

              @@resync_ssh_keys = false
            end

            @@old_valuehash = valuehash.clone
          end
        end

      end

    end
  end
end

Setting.send(:include, OpenProject::Revisions::Git::Patches::SettingPatch)
