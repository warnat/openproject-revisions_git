module OpenProject::GitHosting
  module Patches
    module UserPatch

      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods

          attr_accessor :status_has_changed

          has_many :gitolite_public_keys, :dependent => :destroy

          before_destroy :delete_ssh_keys, prepend: true

          after_save :check_if_status_changed

          after_commit ->(obj) { obj.update_repositories }, on: :update
        end
      end


      module InstanceMethods


        def gitolite_identifier
          "#{Setting.plugin_openproject_git_hosting[:gitolite_identifier_prefix]}#{self.login.underscore}".gsub(/[^0-9a-zA-Z\-]/, '_')
        end


        protected


        def update_repositories
          if status_has_changed
            git_projects = self.projects.uniq.select{|p| p.gitolite_repos.any?}.map{|project| project.id}

            OpenProject::GitHosting::GitHosting.logger.info { "User status has changed, update projects" }
            OpenProject::GitHosting::GitoliteWrapper.update(:update_projects, git_projects)
          end
        end


        private


        def delete_ssh_keys
          OpenProject::GitHosting::GitHosting.logger.info("User '#{self.login}' has been deleted from Redmine delete membership and SSH keys !")
        end


        def check_if_status_changed
          if self.status_changed?
            self.status_has_changed = true
          else
            self.status_has_changed = false
          end
        end

      end


    end
  end
end

User.send(:include, OpenProject::GitHosting::Patches::UserPatch)
