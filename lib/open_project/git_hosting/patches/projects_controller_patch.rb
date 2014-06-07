module OpenProject::GitHosting
  module Patches
    module ProjectsControllerPatch

      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods

          alias_method_chain :update,    :git_hosting
          alias_method_chain :destroy,   :git_hosting
          alias_method_chain :archive,   :git_hosting
          alias_method_chain :unarchive, :git_hosting

          helper :git_hosting
        end
      end


      module InstanceMethods

        def update_with_git_hosting(&block)

          update_without_git_hosting(&block)

          return unless @project.repository.is_a?(Repository::Git)

          byebug

          if @project.repository.url != @project.repository.gitolite_repository_path ||
             @project.repository.url != @project.repository.root_url

            OpenProject::GitHosting::GitHosting.logger.info("Move repositories of project : '#{@project}'")
            OpenProject::GitHosting::GitoliteWrapper.update(:move_repositories, @project.id)
          else
            # Adjust daemon status
            disable_git_daemon_if_not_public
          end
        end


        def destroy_with_git_hosting(&block)
          # Remember all projects with git repositories we have to delete later on.
          # Reverse the list to remove the lowermost repo first.
          destroy_repos = flatten_project_git_repos.reverse

          destroy_without_git_hosting(&block)

          if api_request? || params[:confirm]
            OpenProject::GitHosting::GitoliteWrapper.update(:delete_repositories, destroy_repos)
          end
        end



        def archive_with_git_hosting(&block)
          archive_without_git_hosting(&block)

          # Remove all subprojects from gitolite-admin
          remove_repos = flatten_project_git_repos

          OpenProject::GitHosting::GitHosting.logger.info("Archiving '#{@project}'")
          OpenProject::GitHosting::GitoliteWrapper.update(:remove_repositories, remove_repos)
        end


        def unarchive_with_git_hosting(&block)
          unarchive_without_git_hosting(&block)

          OpenProject::GitHosting::GitHosting.logger.info("Project has been unarchived, update it : '#{@project}'")
          OpenProject::GitHosting::GitoliteWrapper.update(:update_repository, @project.repository)
        end


        private

        # Given a list of projects, returns a list of Git repos
        # of all subprojects with two keys:
        # name, path of the repository
        def flatten_project_git_repos
          projects = @project.self_and_descendants.uniq
            .select{|p| p.repository.is_a?(Repository::Git)}

          projects.map do |project|
            { name: project.repository.gitolite_repository_name,
              path: project.repository.gitolite_repository_path }
          end
        end

        def disable_git_daemon_if_not_public
          # Go through all gitolite repos and disable Git daemon if necessary
          if @project.repository.extra[:git_daemon] && !@project.is_public
            @project.repository.extra[:git_daemon] = false
            @project.repository.extra.save
          end
          OpenProject::GitHosting::GitHosting.logger.info("Set Git daemon for repositories of project : '#{@project}'" )
          OpenProject::GitHosting::GitoliteWrapper.update(:update_repository, @project.repository)
        end
      end
    end
  end
end

ProjectsController.send(:include, OpenProject::GitHosting::Patches::ProjectsControllerPatch)
