module OpenProject::Revisions::Git::GitoliteWrapper
  class Projects < Admin
    include RepositoriesHelper

    def update_projects
      perform_update(@object_id)
    end

    def update_all_projects
      perform_update(Project)
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
      @admin.transaction do
        filter_gitolite(projects).each do |project|
          handle_repository_add(project.repository)
          gitolite_admin_repo_commit(project.identifier)
        end
      end
    end
  end
end
