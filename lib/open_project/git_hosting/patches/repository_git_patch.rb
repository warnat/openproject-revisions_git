require_dependency 'repository/git'

module OpenProject::GitHosting
  module Patches
    module RepositoryGitPatch

      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods
          extend ClassMethods

          has_one  :extra, :foreign_key => 'repository_id', :class_name => 'RepositoryGitExtra', :dependent => :destroy
          accepts_nested_attributes_for :extra

          has_many :repository_mirrors,                :dependent => :destroy, :foreign_key => 'repository_id'
          has_many :repository_post_receive_urls,      :dependent => :destroy, :foreign_key => 'repository_id'
          has_many :repository_deployment_credentials, :dependent => :destroy, :foreign_key => 'repository_id'
          has_many :repository_git_config_keys,        :dependent => :destroy, :foreign_key => 'repository_id'

          before_validation  :set_git_urls
        end
      end

      module ClassMethods

        # Parse a path of the form <proj1>/<proj2>/<proj3>/<projekt>.git and return the specified
        # project identifier.
        #
        # Example: project1/subproject1/myproject.git => 'myproject'

        def find_by_path(path, flags = {})
          identifier = File.basename(path, ".*")
          if (project = Project.find_by_identifier(identifier))
            project.repository
          else
            nil
          end
        end
      end


      module InstanceMethods

        # Returns the hierarchical repository path
        # e.g., "foo/bar.git"
        def git_path
          [gitolite_repository_name, '.git'].join
        end

        # Returns the repository path to locate gitolite
        # (relative from +gitolite_users+ $HOME)
        #
        # e.g., Project Foo, Subproject Bar => 'repositories/foo/bar.git'
        def gitolite_repository_path
          File.join(Setting.plugin_openproject_git_hosting[:gitolite_global_storage_dir],
            git_path)
        end

        # Returns the repository name
        #
        # e.g., Project Foo, Subproject Bar => 'foo/bar'
        def gitolite_repository_name
          if (parent_path = get_full_parent_path).empty?
            project.identifier
          else
            File.join(parent_path, project.identifier)
          end
        end

        def http_user_login
          User.current.anonymous? ? "" : "#{User.current.login}@"
        end


        def http_access_path
          "#{Setting.plugin_openproject_git_hosting[:http_server_subdir]}#{git_path}"
        end


        def ssh_url
          "ssh://#{Setting.plugin_openproject_git_hosting[:gitolite_user]}@#{Setting.plugin_openproject_git_hosting[:ssh_server_domain]}/#{git_path}"
        end


        def git_url
          "git://#{Setting.plugin_openproject_git_hosting[:ssh_server_domain]}/#{git_path}"
        end


        def http_url
          "http://#{http_user_login}#{Setting.plugin_openproject_git_hosting[:http_server_domain]}/#{http_access_path}"
        end


        def https_url
          "https://#{http_user_login}#{Setting.plugin_openproject_git_hosting[:https_server_domain]}/#{http_access_path}"
        end


        def available_urls
          hash = {}

          commiter = User.current.allowed_to?(:commit_access, project) ? 'true' : 'false'

          ssh_access = {
            :url      => ssh_url,
            :commiter => commiter
          }

          https_access = {
            :url      => https_url,
            :commiter => commiter
          }

          ## Unsecure channels (clear password), commit is disabled
          http_access = {
            :url      => http_url,
            :commiter => 'false'
          }

          git_access = {
            :url      => git_url,
            :commiter => 'false'
          }

          if !User.current.anonymous?
            if User.current.allowed_to?(:create_gitolite_ssh_key, nil, :global => true)
              hash[:ssh] = ssh_access
            end
          end

          if extra[:git_http] == 1
            hash[:https] = https_access
          end

          if extra[:git_http] == 2
            hash[:https] = https_access
            hash[:http] = http_access
          end

          if extra[:git_http] == 3
            hash[:http] = http_access
          end

          if project.is_public && extra[:git_daemon] == 1
            hash[:git] = git_access
          end

          return hash
        end


        def get_full_parent_path
          parent_parts = []
          p = project
          while p.parent
            parent_id = p.parent.identifier.to_s
            parent_parts.unshift(parent_id)
            p = p.parent
          end

          return parent_parts.join("/")
        end

        def gitolite_hook_key
          self.extra.key
        end


        private

        # Set up git urls for new repositories
        def set_git_urls
          self.url = self.gitolite_repository_path if self.url.blank?
          self.root_url = self.url if self.root_url.blank?
        end
      end

    end
  end
end

