class UpdateMultiRepoPerProject < ActiveRecord::Migration

  def self.up

    if !columns("repository_mirrors").index{|x| x.name=="repository_id"}
      add_column :repository_mirrors, :repository_id, :integer
      begin
        say "Detaching repository mirrors from projects; attaching them to repositories..."
        RepositoryMirror.all.each do |mirror|
          mirror.repository_id = Project.find(mirror.project_id).repository.id
          mirror.save!
        end
        say "Success.  Changed #{RepositoryMirror.all.count} records."
      rescue => e
        say "Failed to attach repository mirrors to repositories."
        say "Error: #{e.message}"
      end
      if columns("repository_mirrors").index{|x| x.name=="project_id"}
        remove_column :repository_mirrors, :project_id
      end
    end

    if !columns("repository_post_receive_urls").index{|x| x.name=="repository_id"}
      add_column :repository_post_receive_urls, :repository_id, :integer
      begin
        say "Detaching repository post-receive-urls from projects; attaching them to repositories..."
        RepositoryPostReceiveUrl.all.each do |prurl|
          prurl.repository_id = Project.find(prurl.project_id).repository.id
          prurl.save!
        end
        say "Success.  Changed #{RepositoryPostReceiveUrl.all.count} records."
      rescue => e
        say "Failed to attach repositories post-receive-urls to repositories."
        say "Error: #{e.message}"
      end
      if columns("repository_post_receive_urls").index{|x| x.name=="project_id"}
        remove_column :repository_post_receive_urls, :project_id
      end
    end

    if columns("repositories").index{|x| x.name=="identifier"}
      add_index :repositories, [:identifier]
      add_index :repositories, [:identifier, :project_id]
    end
    rename_column :git_caches, :proj_identifier, :repo_identifier

  end

  def self.down

    if !columns("repository_mirrors").index{|x| x.name=="project_id"}
      add_column :repository_mirrors, :project_id, :integer
      begin
        say "Detaching repository mirrors from repositories; re-attaching them to projects..."
        RepositoryMirror.all.each do |mirror|
          mirror.project_id = Repository.find(mirror.repository_id).project.id
          mirror.save!
        end
        say "Success.  Changed #{RepositoryMirror.all.count} records."
      rescue => e
        say "Failed to re-attach repository mirrors to projects."
        say "Error: #{e.message}"
      end
      if columns("repository_mirrors").index{|x| x.name=="repository_id"}
        remove_column :repository_mirrors, :repository_id
      end
    end

    if !columns("repository_post_receive_urls").index{|x| x.name=="project_id"}
      add_column :repository_post_receive_urls, :project_id, :integer
      begin
        say "Detaching repository post-receive-urls from repositories; re-attaching them to projects..."
        RepositoryPostReceiveUrl.all.each do |prurl|
          prurl.project_id = Repository.find(prurl.repository_id).project.id
          prurl.save!
        end
        say "Success.  Changed #{RepositoryPostReceiveUrl.all.count} records."
      rescue => e
        say "Failed to re-attach repository post-receive urls to projects."
        say "Error: #{e.message}"
      end
      if columns("repository_post_receive_urls").index{|x| x.name=="repository_id"}
        remove_column :repository_post_receive_urls, :repository_id
      end
    end

    if columns("repositories").index{|x| x.name=="identifier"}
      remove_index :repositories, [:identifier]
      remove_index :repositories, [:identifier, :project_id]
    end
    rename_column :git_caches, :repo_identifier, :proj_identifier

  end

end
