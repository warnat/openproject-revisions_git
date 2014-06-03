
require Rails.root.join("db","migrate","migration_utils","migration_squasher").to_s
require Rails.root.join("db","migrate","migration_utils","setting_renamer").to_s
require 'open_project/plugins/migration_mapping'
# This migration aggregates the migrations detailed in MIGRATION_FILES
class AggregatedGitHostingMigrations < ActiveRecord::Migration

  MIGRATION_FILES = <<-MIGRATIONS
    20091119162426_set_mirror_role_permissions.rb
    20091119162427_create_gitolite_public_keys.rb
    20091119162428_create_git_caches.rb
    20110726000000_extend_changesets_notified_cia.rb
    20110807000000_create_repository_mirrors.rb
    20110813000000_create_git_repository_extras.rb
    20110817000000_move_notified_cia_to_git_cia_notifications.rb
    20111119170948_add_indexes_to_gitolite_public_key.rb
    20120521000000_create_repository_post_receive_urls.rb
    20120521000010_set_post_receive_url_role_permissions.rb
    20120522000000_add_post_receive_url_modes.rb
    20120710204007_add_repository_mirror_fields.rb
    20120803043256_create_deployment_credentials.rb
    20120904060609_update_multi_repo_per_project.rb
    20130909195727_create_repository_git_notifications.rb
    20130909195828_rename_table_git_repository_extras.rb
    20130909195929_rename_table_deployment_credentials.rb
    20130910195930_add_columns_to_repository_git_extra.rb
    20130910195931_add_columns_to_repository_git_notification.rb
    20140305053200_remove_notify_cia.rb
    20140305083200_add_default_branch_to_repository_git_extra.rb
    20140306002300_create_repository_git_config_keys.rb
    20140327015700_create_github_issues.rb
    20140327015701_create_github_comments.rb
    20140417004100_enforce_models_constraints.rb
  MIGRATIONS

  OLD_PLUGIN_NAME = "redmine_git_hosting"

  def up
    migration_names = OpenProject::Plugins::MigrationMapping.migration_files_to_migration_names(MIGRATION_FILES, OLD_PLUGIN_NAME)
    Migration::MigrationSquasher.squash(migration_names) do


      create_table :gitolite_public_keys do |t|
        t.column :title, :string, :null => false
        t.column :identifier, :string, :null => false
        t.column :key, :text, :null => false
        t.column :active, :boolean, :default => true
        t.column :key_type, :integer, :null => false,
                 :default => GitolitePublicKey::KEY_TYPE_USER
        t.column :delete_when_unused, :boolean, :default => true
        t.references :user, :null => false
        t.timestamps
      end

      add_index :gitolite_public_keys, :user_id
      add_index :gitolite_public_keys, :identifier

      create_table :git_caches do |t|
        t.column :command, :text, :null => false
        t.column :command_output, :binary, :null => false
        t.column :proj_identifier, :string
        t.timestamps
      end

      create_table :repository_mirrors do |t|
        t.references :project, :null => false
        t.column :active, :boolean, :default => true
        t.column :url, :string, :null => false
        t.column :push_mode, :integer, :default => 0, :null => false
        t.column :include_all_branches, :boolean, :default => false
        t.column :include_all_tags, :boolean, :default => false
        t.column :explicit_refspec, :string, :default => ""
        t.references :project
        t.timestamps
      end

      create_table :repository_git_extras do |t|
        t.references :repository, :null => false
        t.column :git_daemon, :boolean, :default => true
        t.column :git_http,   :boolean, :default => true
        t.column :git_notify, :boolean, :default => false
        t.column :default_branch, :string, :null => false
        t.column :key, :string, :null => false
      end

      create_table :repository_post_receive_urls do |t|
        t.references :project, :null => false
        t.column :active, :boolean, :default => true
        t.column :url, :string, :null => false
        t.column :mode, :string, :default => "github"
        t.references :project
        t.timestamps
      end

      create_table :repository_deployment_credentials do |t|
        t.references :repository, :null => false
        t.references :gitolite_public_key, :null => false
        t.references :user, :null => false
        t.column :active, :boolean, :default => true
        t.column :perm, :string, :null => false
      end
      add_index :repository_deployment_credentials, :gitolite_public_key_id,
        :name => 'index_deployment_credentials_on_gitolite_pk_id'

      create_table :repository_git_config_keys do |t|
        t.references :repository, :null => false
        t.column :key,   :string, :null => false
        t.column :value, :string, :null => false
      end

      create_table :github_issues do |t|
        t.column :github_id, :integer, :null => false
        t.column :issue_id,  :integer, :null => false
      end

      create_table :github_comments do |t|
        t.column :github_id,  :integer, :null => false
        t.column :journal_id, :integer, :null => false
      end


      #
      # Roles
      #

      manager_role_name = I18n.t(:default_role_manager, {:locale => 'en'})
      puts "Updating role : '#{manager_role_name}'..."
      manager_role = Role.find_by_name(manager_role_name)
      if !manager_role.nil?
        # Repo mirrors
        manager_role.add_permission! :view_repository_mirrors
        manager_role.add_permission! :create_repository_mirrors
        manager_role.add_permission! :edit_repository_mirrors
        # Post URLs
        manager_role.add_permission! :view_repository_post_receive_urls
        manager_role.add_permission! :create_repository_post_receive_urls
        manager_role.add_permission! :edit_repository_post_receive_urls
        # Deployment Keys
        manager_role.add_permission! :view_deployment_keys
        manager_role.add_permission! :create_deployment_keys
        manager_role.add_permission! :edit_deployment_keys
        manager_role.save
        puts "done !"
      else
        puts "Role '#{manager_role_name}' not found, exit !"
      end

      developer_role_name = I18n.t(:default_role_developer, {:locale => 'en'})
      puts "Updating role : '#{developer_role_name}'..."
      developer_role = Role.find_by_name(developer_role_name)
      if !developer_role.nil?
        developer_role.add_permission! :view_repository_mirrors
        developer_role.add_permission! :view_repository_post_receive_urls
        developer_role.add_permission! :view_deployment_keys
        developer_role.save
        puts "done !"
      else
        puts "Role '#{developer_role_name}' not found, exit !"
      end



    end

    Migration::SettingRenamer.rename(OLD_PLUGIN_NAME, "plugin_openproject_git_hosting")
  end

  def down


    drop_table :gitolite_public_keys
    drop_table :git_caches
    drop_table :repository_mirrors
    drop_table :repository_git_extras
    drop_table :repository_post_receive_urls
    drop_table :repository_deployment_credentials
    drop_table :repository_git_config_keys
    drop_table :github_issues
    drop_table :github_comments


    #
    # Roles
    #

    manager_role_name = I18n.t(:default_role_manager, {:locale => 'en'})
    manager_role = Role.find_by_name(manager_role_name)
    if !manager_role.nil?
      # Repo mirrors
      manager_role.remove_permission! :view_repository_mirrors
      manager_role.remove_permission! :create_repository_mirrors
      manager_role.remove_permission! :edit_repository_mirrors
      # Post URLs
      manager_role.remove_permission! :view_repository_post_receive_urls
      manager_role.remove_permission! :create_repository_post_receive_urls
      manager_role.remove_permission! :edit_repository_post_receive_urls
      # Deployment Keys
      manager_role.remove_permission! :view_deployment_keys
      manager_role.remove_permission! :create_deployment_keys
      manager_role.remove_permission! :edit_deployment_keys

      manager_role.save
    end

    developer_role_name = I18n.t(:default_role_developer, {:locale => 'en'})
    developer_role = Role.find_by_name(developer_role_name)
    if !developer_role.nil?
      developer_role.remove_permission! :view_repository_mirrors
      developer_role.remove_permission! :view_repository_post_receive_urls
      developer_role.remove_permission! :view_deployment_keys
      developer_role.save
      puts "done !"
    end
  end
end



