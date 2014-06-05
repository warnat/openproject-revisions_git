module OpenProject::GitHosting::GitoliteWrapper
  class Projects < Admin

    include RepositoriesHelper

    def update_projects
      perform_update(@object_id)
    end

    def update_all_projects
      projects = Project.active_or_archived.includes(:repositories).all
      perform_update(projects)
    end

    def move_repositories
      project = Project.find_by_id(@object_id)

      @admin.transaction do
        @delete_parent_path = []
        handle_repositories_move(project)
        clean_path(@delete_parent_path)
      end
    end


    def move_repositories_tree
      projects = Project.active_or_archived.includes(:repositories).all.select { |x| x.parent_id.nil? }

      @admin.transaction do
        @delete_parent_path = []

        projects.each do |project|
          handle_repositories_move(project)
        end

        clean_path(@delete_parent_path)
      end
    end


    private


    # Updates a set of projects by re-adding
    # them to gitolite.
    #
    def perform_update(*projects)
      @admin.transaction do
        projects.each do |project|

          next unless project.repository.is_a?(Repository::Git)
          
          handle_repository_add(project.repository)
          gitolite_admin_repo_commit("#{project.identifier}")
        end
      end
    end

  end
end
