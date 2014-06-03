module OpenProject::GitHosting::GitoliteWrapper
  class Projects < Admin

    include RepositoriesHelper

    def update_projects
      # Reduce list to available projects
      filtered = [*@object_id].map { |id| Project.find_by_id(id) }.compact
      perform_update(filtered)
    end

    def update_all_projects
      projects = Project.active_or_archived.includes(:repositories).all
      perform_update(projects)
    end


    def update_all_projects_forced
      projects = Project.active_or_archived.includes(:repositories).all
      update_projects_forced(projects)
    end


    def update_members
      project = Project.find_by_id(@object_id)
      perform_update(project)
    end


    def update_role
      object = []
      role = Role.find_by_id(@object_id)
      if !role.nil?
        projects = role.members.map(&:project).flatten.uniq.compact
        if projects.length > 0
          object = projects
        end
      end

      perform_update(object)
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


    def perform_update(*projects)
      @admin.transaction do
        projects.each do |project|
          handle_project_update(project)
          gitolite_admin_repo_commit("#{project.identifier}")
        end
      end
    end


    def update_projects_forced(*projects)
      @admin.transaction do
        projects.each do |project|
          handle_project_update(project, true)
          gitolite_admin_repo_commit("#{project.identifier}")
        end
      end
    end


    def handle_project_update(project, force = false)

      return unless project.repository.is_a?(Repository::Git)
      if force == true
        handle_repository_add(project.repository, :force => true)
      else
        handle_repository_update(project.repository)
      end
    end
  end
end
