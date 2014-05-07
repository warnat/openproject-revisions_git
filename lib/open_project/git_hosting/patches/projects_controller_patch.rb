module OpenProject::GitHosting
  module Patches
    module ProjectsControllerPatch

      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          unloadable

          alias_method_chain :create,    :git_hosting
          alias_method_chain :update,    :git_hosting
          alias_method_chain :destroy,   :git_hosting
          alias_method_chain :archive,   :git_hosting
          alias_method_chain :unarchive, :git_hosting

          helper :git_hosting
        end
      end


      module InstanceMethods

        def create_with_git_hosting(&block)
          create_without_git_hosting(&block)

          # Only create repo if project creation worked
          if validate_parent_id && @project.save
            git_repo_init
          end
        end


        def update_with_git_hosting(&block)
          update_without_git_hosting(&block)

          update = true

          if @project.gitolite_repos.detect {|repo| repo.url != repo.gitolite_repository_path || repo.url != repo.root_url}
            # Hm... something about parent hierarchy changed.  Update us and our children
            update = false

            OpenProject::GitHosting::GitHosting.logger.info("Move repositories of project : '#{@project}'")
            OpenProject::GitHosting::GitoliteWrapper.(:move_repositories, @project.id)
          end

          # Adjust daemon status
          disable_git_daemon_if_not_public if update
        end


        def destroy_with_git_hosting(&block)
          destroy_repositories = []

          projects = @project.self_and_descendants

          # Only take projects that have Git repos.
          git_projects = projects.uniq.select{|p| p.gitolite_repos.any?}

          git_projects.reverse.each do |project|
            project.gitolite_repos.reverse.each do |repository|
              repository_data = {}
              repository_data['repo_name']   = repository.gitolite_repository_name
              repository_data['repo_path']   = repository.gitolite_repository_path
              destroy_repositories.push(repository_data)
            end
          end

          destroy_without_git_hosting(&block)

          if api_request? || params[:confirm]
            OpenProject::GitHosting::GitoliteWrapper.update(:delete_repositories, destroy_repositories)
          end
        end


        def archive_with_git_hosting(&block)
          archive_without_git_hosting(&block)
          update_projects("Project has been archived, update it : '#{@project}'")
        end


        def unarchive_with_git_hosting(&block)
          unarchive_without_git_hosting(&block)

          OpenProject::GitHosting::GitHosting.logger.info("Project has been unarchived, update it : '#{@project}'")
          OpenProject::GitHosting::GitoliteWrapper.update(:update_project, @project.id)
        end


        private


        def update_projects(message)
          projects = @project.self_and_descendants

          # Only take projects that have Git repos.
          git_projects = projects.uniq.select{|p| p.gitolite_repos.any?}.map{|project| project.id}

          OpenProject::GitHosting::GitHosting.logger.info(message)
          OpenProject::GitHosting::GitoliteWrapper.update(:update_projects, git_projects)
        end


        def git_repo_init
          if @project.module_enabled?('repository') && OpenProject::GitHosting::GitoliteWrapper.true?(:all_projects_use_git)
            # Create new repository
            repository = Repository.factory("Git")
            repository.is_default = true
            @project.repositories << repository

            options = { :create_readme_file => OpenProject::GitHosting::GitoliteWrapper.true?(:init_repositories_on_create) }


            OpenProject::GitHosting::GitHosting.logger.info("User '#{User.current.login}' created a new repository '#{repository.gitolite_repository_name}'" )
            OpenProject::GitHosting::GitoliteWrapper.update(:update_projects, @project.id)
          end
        end


        def disable_git_daemon_if_not_public
          # Go through all gitolite repos and diable Git daemon if necessary
          @project.gitolite_repos.each do |repository|
            if repository.extra[:git_daemon] && !@project.is_public
              repository.extra[:git_daemon] = false
              repository.extra.save
            end
          end
          OpenProject::GitHosting::GitHosting.logger.info("Set Git daemon for repositories of project : '#{@project}'" )
          OpenProject::GitHosting::GitoliteWrapper.update(:update_projects, @project.id)
        end
      end
    end
  end
end

unless ProjectsController.included_modules.include?(OpenProject::GitHosting::Patches::ProjectsControllerPatch)
  ProjectsController.send(:include, OpenProject::GitHosting::Patches::ProjectsControllerPatch)
end
