module OpenProject::Revisions::Git::GitoliteWrapper
  class Projects < Admin
    include RepositoriesHelper

    def update_projects
      @admin.transaction do
        perform_update(@object_id)
      end
    end

    def update_all_projects
      @admin.transaction do
        perform_update(Project)
      end
    end

    ##
    # Forces resynchronization with the gitolite config for all repositories
    # with a current configuration.
    #
    # Truncates the +openproject.conf+ file prior to synchronization
    # so that all configurations made from the plugin are reset.
    def sync_with_gitolite
      @admin.transaction do
        byebug
        admin.truncate!
        gitolite_admin_repo_commit("Truncated configuration")
        perform_update(@object_id)
      end
    end

    def move_repositories
      projects = Project.find_by_id(@object_id).self_and_descendants

      # Only take projects that have Git repos.
      gitolite_projects = filter_gitolite(projects)
      return if gitolite_projects.empty?

      @admin.transaction do
        handle_repositories_move(gitolite_projects)
      end
    end

    private

    ##
    # Find gitolite projects
    def filter_gitolite(projects)
      projects.includes(:repository)
              .where('repositories.type = ?', 'Repository::Gitolite')
              .references('repositories')
    end

    # Updates a set of projects by re-adding
    # them to gitolite.
    #
    def perform_update(projects)
      repos = filter_gitolite(projects)
      return unless repos.size > 0

      message = "Updated projects:\n"
      repos.each do |project|
        handle_repository_add(project.repository)
        message << " - #{project.identifier}\n"
      end

      gitolite_admin_repo_commit(message)
    end
  end
end
