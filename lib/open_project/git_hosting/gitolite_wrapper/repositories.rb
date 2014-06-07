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
    # 2. Delete the physical repository
    # (and all empty parent directories within the repository storage)
    def delete_repositories
      handle_repository_delete(@object_id) do |repo|

        # Delete all empty parent directories
        # From the lowermost repository
        clean_repo_dir(repo[:path])
      end
    end

  end
end
