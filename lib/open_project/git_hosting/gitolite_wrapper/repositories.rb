module OpenProject::GitHosting::GitoliteWrapper
  class Repositories < Admin

    include OpenProject::GitHosting::GitoliteWrapper::RepositoriesHelper


    def add_repository
      repository = @object_id

      @admin.transaction do

        handle_repository_add(repository)

        gitolite_admin_repo_commit("#{repository.gitolite_repository_name}")
        logger.info { "#{@action} : let Gitolite create empty repository '#{repository.gitolite_repository_path}'" }
      end
    end


    def update_repository
      repository = @object_id

      # We override the repository in gitolite anyway
      add_repository

      # Treat options
      if @options.has_key?(:delete_git_config_key) && !@options[:delete_git_config_key].empty?
        delete_hook_param(repository, @options[:delete_git_config_key])
      end
    end

    # Remove the given repositories from gitolite-admin
    # Does NOT remove the repository from filesystem.
    def remove_repositories
      handle_repository_delete(@object_id)
    end


    # Delete the given repositories.
    #
    # As the project/repo model may be deleted already,
    # receives an array of repo name and path.
    #
    # Performs two steps
    # 1. Delete the reposistory from gitolite-admin (and commit)
    # 2. Depending on the setting :delete_git_repositories
    #  (true) Delete the physical repository
    #  (false) Move the physical repository to the recycle location
    def delete_repositories
      if Setting.plugin_openproject_git_hosting[:delete_git_repositories]
        handle_repository_delete(@object_id) do |repo|
          byebug
          OpenProject::GitHosting::GitoliteWrapper::sudo_rmdir(repo[:path])
        end
      else
        handle_repository_delete(@object_id) do |repo|
          recycle = OpenProject::GitHosting::Recycle.new
          recycle.move_repository_to_recycle(repo)
        end
      end
    end


    def update_repository_default_branch
      repository = Repository.find_by_id(@object_id)

      begin
        OpenProject::GitHosting.execute_command(:git_cmd, "--git-dir='#{repository.gitolite_repository_path}' symbolic-ref HEAD refs/heads/#{repository.extra[:default_branch]}")
        logger.info { "Default branch successfully updated for repository '#{repository.gitolite_repository_name}'"}
      rescue GitHosting::GitHostingException => e
        logger.error { "Error while updating default branch for repository '#{repository.gitolite_repository_name}'"}
      end

      OpenProject::GitHosting::Cache.clear_cache_for_repository(repository)

      logger.info { "Fetch changesets for repository '#{repository.gitolite_repository_name}'"}
      repository.fetch_changesets
    end
  end
end
