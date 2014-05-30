module OpenProject::GitHosting::GitoliteWrapper
  class Repositories < Admin

    include OpenProject::GitHosting::GitoliteWrapper::RepositoriesHelper


    def add_repository
      repository = Repository.find_by_id(@object_id)

      @admin.transaction do

        handle_repository_add(repository)

        gitolite_admin_repo_commit("#{repository.gitolite_repository_name}")
        logger.info { "#{@action} : let Gitolite create empty repository '#{repository.gitolite_repository_path}'" }
      end
    end


    def update_repository
      repository = Repository.find_by_id(@object_id)

      @admin.transaction do
        handle_repository_update(repository)
        gitolite_admin_repo_commit("#{repository.gitolite_repository_name}")
      end

      # Treat options
      if @options.has_key?(:delete_git_config_key) && !@options[:delete_git_config_key].empty?
        delete_hook_param(repository, @options[:delete_git_config_key])
      end
    end


    def delete_repositories
      repositories_array = @object_id

      @admin.transaction do
        repositories_array.each do |repository_data|
          handle_repository_delete(repository_data)

          recycle = OpenProject::GitHosting::Recycle.new
          recycle.move_repository_to_recycle(repository_data) if @delete_git_repositories

          gitolite_admin_repo_commit("#{repository_data['repo_name']}")
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
