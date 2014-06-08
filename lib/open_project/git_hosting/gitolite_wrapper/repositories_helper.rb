require 'pathname'
module OpenProject::GitHosting::GitoliteWrapper
  module RepositoriesHelper

    def handle_repository_add(repository, opts = {})
      repo_name = repository.gitolite_repository_name
      repo_path = repository.gitolite_repository_path
      project   = repository.project

      if @gitolite_config.repos[repo_name]
        logger.warn("#{@action} : repository '#{repo_name}' already exists in Gitolite, removing first")
        @gitolite_config.rm_repo(repo_name)
      end

      # Create new repo object
      repo_conf = Gitolite::Config::Repo.new(repo_name)
      set_repo_config_keys(repo_conf, repository)

      @gitolite_config.add_repo(repo_conf)
      repo_conf.permissions = [build_permissions(repository)]
    end


    #
    # Sets the git config-keys for the given repo configuration
    #
    def set_repo_config_keys(repo_conf, repository)
      # Set post-receive hook params
      repo_conf.set_git_config("openproject.githosting.projectid", repository.project.identifier.to_s)
      repo_conf.set_git_config("openproject.githosting.repositorykey", repository.extra[:key])
      repo_conf.set_git_config("http.uploadpack", (User.anonymous.allowed_to?(:view_changesets, repository.project) ||
        repository.extra[:git_http]))

      # Set Git config keys
      repository.repository_git_config_keys.each do |config_entry|
        repo_conf.set_git_config(config_entry.key, config_entry.value)
      end
    end

    # Delete the reposistory from gitolite-admin (and commit)
    # and yield (e.g., for deletion / moving to trash before commit)
    #
    def handle_repository_delete(repos)
      @admin.transaction do
        repos.each do |repo|
          if @gitolite_config.repos[repo[:name]]

            # Delete from in-memory gitolite
            @gitolite_config.rm_repo(repo[:name])

            # Allow post-processing of removed repo
            yield repo

            # Commit changes
            gitolite_admin_repo_commit(repo[:name])
          else
            logger.warn("#{@action} : '#{repo[:name]}' does not exist in Gitolite")
          end
        end
      end
    end


    # Move a list of git repositories to their new location
    #
    # The old repository location is expected to be available from its url.
    # Upon moving the project (e.g., to a subproject),
    # the repository's url will still reflect its old location.
    def handle_repositories_move(repos)

      # We'll ned the repository root directory.
      gitolite_repos_root = Pathname.new(Setting.plugin_openproject_git_hosting[:gitolite_global_storage_dir])

      repos.each do |repo|

        # Old repository location: <:gitolite_global_storage_dir>/<path>
        old_repository_path = Pathname.new(repo.url)

        # Old name is the <path> section of above, thus extract it from url.
        # But remove the '.git' part.
        old_repository_name = old_repository_path.relative_path_from(gitolite_repos_root)
          .basename('.git').to_s

        # Actually move the repository
        do_move_repository(repo, old_repository_path.to_s, old_repository_name)

        gitolite_admin_repo_commit("#{@action} : #{repo.project.identifier}")
      end
    end


    # Move a repository in gitolite-admin from its old entry to a new one
    #
    # This involves the following steps:
    # 1. Remove the old entry (+old_name+)
    # 2. Move the physical repository on filesystem.
    # 3. Add the repository using +repo.gitolite_repository_name+
    #
    def do_move_repository(repo, old_path, old_name)

      new_name  = repo.gitolite_repository_name
      new_path  = repo.gitolite_repository_path

      logger.info("#{@action} : Moving '#{old_name}' -> '#{new_name}'")
      logger.debug("-- On filesystem, this means '#{old_path}' -> '#{new_path}'")

      # Remove old config entry
      old_repo_conf = @gitolite_config.rm_repo(old_name)

      # Move the repo on filesystem
      move_physical_repo(old_path, new_path)

      # Add the repo as new
      handle_repository_add(repo)

    end

    def move_physical_repo(old_path, new_path)

      if old_path == new_path
        logger.warn("#{@action} : old repository and new repository are identical '#{old_path}' .. why move?")
        return
      end

      # Now we have multiple options, due to the way gitolite sets up repositories
      new_path_exists = OpenProject::GitHosting::GitoliteWrapper.file_exists?(new_path)
      old_path_exists = OpenProject::GitHosting::GitoliteWrapper.file_exists?(old_path)

      # If the new path exists, some old project wasn't correctly cleaned.
      if new_path_exists
        logger.warn("#{@action} : New location '#{new_path}' was non-empty. Cleaning first.")
        clean_repo_dir(new_path)
      end

      # Old repository has never been created by gitolite
      # => No need to move anything on the disk
      if !old_path_exists
        logger.info("#{@action} : Old location '#{old_path}' was never created. Skipping disk movement.")
        return
      end

      # Otherwise, move the old repo
      OpenProject::GitHosting::GitoliteWrapper.sudo_move(old_path, new_path)

      # Clean up the old path
      clean_repo_dir(old_path)
    end

    # Removes the repository path and all parent repositories that are empty
    #
    # (i.e., if moving foo/bar/repo.git to foo/repo.git, foo/bar remains and is possibly abandoned)
    # This moves up from the lowermost point, and deletes all empty directories.
    def clean_repo_dir(path)
      parent = Pathname.new(path).parent
      repo_root = Pathname.new(Setting.plugin_openproject_git_hosting[:gitolite_global_storage_dir])

      # Delete the repository project itself.
      OpenProject::GitHosting::GitoliteWrapper::sudo_rmdir(path, true)

      loop do

        parent_repo = parent.to_s

        # Stop deletion upon finding a non-empty parent repository
        break unless OpenProject::GitHosting::GitoliteWrapper::sudo_directory_empty?(parent_repo)

        # Stop if we're in the project root
        break if parent_repo == repo_root

        logger.info("#{@action} : Cleaning repository directory #{parent_repo.to_s} ... ")
        OpenProject::GitHosting::GitoliteWrapper::sudo_rmdir(parent_repo)
        parent = parent.parent

      end
    end

    # Builds the set of permissions for all
    # users and deploy keys of the repository
    #
    def build_permissions(repository)
      users   = repository.project.member_principals.map(&:user).compact.uniq
      project = repository.project

      rewind = []
      write  = []
      read   = []

      rewind_users = users.select{|user| user.allowed_to?(:manage_repository, project)}
      write_users  = users.select{|user| user.allowed_to?(:commit_access, project)} - rewind_users
      read_users   = users.select{|user| user.allowed_to?(:view_changesets, project)} - rewind_users - write_users

      if project.active?
        rewind = rewind_users.map{|user| user.gitolite_identifier}
        write  = write_users.map{|user| user.gitolite_identifier}
        read   = read_users.map{|user| user.gitolite_identifier}

        ## DEPLOY KEY
        repository.repository_deployment_credentials.active.each do |cred|
          if cred.perm == "RW+"
            rewind << cred.gitolite_public_key.owner
          elsif cred.perm == "R"
            read << cred.gitolite_public_key.owner
          end
        end

        read << "DUMMY_REDMINE_KEY" if read.empty? && write.empty? && rewind.empty?
        read << "gitweb" if User.anonymous.allowed_to?(:browse_repository, project) && repository.extra[:git_http] != 0
        read << "daemon" if User.anonymous.allowed_to?(:view_changesets, project) && repository.extra[:git_daemon]
      elsif project.archived?
        read << "REDMINE_ARCHIVED_PROJECT"
      else
        all_read = rewind_users + write_users + read_users
        read     = all_read.map{|user| user.gitolite_identifier}
        read << "REDMINE_CLOSED_PROJECT" if read.empty?
      end

      permissions = {}
      permissions["RW+"] = {"" => rewind.uniq.sort} unless rewind.empty?
      permissions["RW"] = {"" => write.uniq.sort} unless write.empty?
      permissions["R"] = {"" => read.uniq.sort} unless read.empty?

      permissions
    end

    def delete_hook_param(repository, parameter_name)
      begin
        GitHosting.execute_command(:git_cmd, "--git-dir='#{repository.gitolite_repository_path}' config --local --unset #{parameter_name}")
        logger.info { "Git config key '#{parameter_name}' successfully deleted for repository '#{repository.gitolite_repository_name}'"}
      rescue GitHosting::GitHostingException => e
        logger.error { "Error while deleting Git config key '#{parameter_name}' for repository '#{repository.gitolite_repository_name}'"}
      end
    end


    def delete_hook_section(repository, section_name)
      begin
        GitHosting.execute_command(:git_cmd, "--git-dir='#{repository.gitolite_repository_path}' config --local --remove-section #{section_name} || true")
        logger.info { "Git config section '#{section_name}' successfully deleted for repository '#{repository.gitolite_repository_name}'"}
      rescue GitHosting::GitHostingException => e
        logger.error { "Error while deleting Git config section '#{section_name}' for repository '#{repository.gitolite_repository_name}'"}
      end
    end


  end
end
