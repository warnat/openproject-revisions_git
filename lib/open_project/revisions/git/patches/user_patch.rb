module OpenProject::Revisions::Git
  module Patches
    module UserPatch
      def self.included(base)
        base.class_eval do

          include InstanceMethods

          attr_accessor :status_has_changed

          has_many :gitolite_public_keys, dependent: :destroy

          before_destroy :delete_ssh_keys, prepend: true

          after_save :check_if_status_changed

          after_commit ->(obj) { obj.update_repositories }, on: :update
        end
      end

      module InstanceMethods
        #
        # Returns a unique identifier for this user to use for gitolite keys.
        # As login names may change (i.e., user renamed), we use the user id
        # with its login name as a prefix for readibility.
        def gitolite_identifier
          [login.underscore.gsub(/[^0-9a-zA-Z\-]/, '_'), '_', id].join
        end

        protected

        def update_repositories
          if status_has_changed
            OpenProject::Revisions::Git::GitoliteWrapper.logger.info(
              "User '#{login}' status has changed, update projects"
            )
            OpenProject::Revisions::Git::GitoliteWrapper.update(:update_projects, projects)
          end
        end

        private

        def delete_ssh_keys
          OpenProject::Revisions::Git::GitoliteWrapper.logger.info(
            "User '#{login}' has been deleted from Redmine delete membership and SSH keys !"
          )
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

User.send(:include, OpenProject::Revisions::Git::Patches::UserPatch)
