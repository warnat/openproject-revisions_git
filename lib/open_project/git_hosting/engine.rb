module OpenProject::GitHosting
  class Engine < ::Rails::Engine
    engine_name :openproject_git_hosting


    def self.settings 
      { 
        :partial => 'settings/openproject_git_hosting',
        :default => {
        # Gitolite SSH Config
        :gitolite_user                  => 'git',
        :gitolite_server_port           => '22',
        :gitolite_ssh_private_key       => '', #Rails.root.join('plugins', 'openproject_git_hosting', 'ssh_keys', 'redmine_gitolite_admin_id_rsa').to_s,
        :gitolite_ssh_public_key        => '', #Rails.root.join('plugins', 'openproject_git_hosting', 'ssh_keys', 'redmine_gitolite_admin_id_rsa.pub').to_s,

        # Gitolite Storage Config
        :gitolite_global_storage_dir    => 'repositories/',
        :gitolite_redmine_storage_dir   => '',
        :gitolite_recycle_bin_dir       => 'recycle_bin/',

        # Gitolite Config File
        :gitolite_config_file                  => 'gitolite.conf',
        :gitolite_config_has_admin_key         => true,
        :gitolite_identifier_prefix            => 'redmine_',

        # Gitolite Global Config
        :gitolite_temp_dir                     => '', # Rails.root.join('tmp', 'openproject_git_hosting').to_s,
        :gitolite_scripts_dir                  => './',
        :gitolite_timeout                      => 10,
        :gitolite_recycle_bin_expiration_time  => 24.0,
        :gitolite_log_level                    => 'info',
        :gitolite_log_split                    => false,
        :git_config_username                   => 'Redmine Git Hosting',
        :git_config_email                      => 'redmine@example.com',

        # Gitolite Hooks Config
        :gitolite_hooks_are_asynchronous  => false,
        :gitolite_force_hooks_update      => true,
        :gitolite_hooks_debug             => false,

        # Gitolite Cache Config
        :gitolite_cache_max_time          => 86400,
        :gitolite_cache_max_size          => 16,
        :gitolite_cache_max_elements      => 2000,

        # Gitolite Access Config
        :ssh_server_domain                => 'localhost',
        :http_server_domain               => 'localhost',
        :https_server_domain              => '',
        :http_server_subdir               => '',
        :show_repositories_url            => true,
        :gitolite_daemon_by_default       => false,
        :gitolite_http_by_default         => 1,

        # Redmine Config
        :all_projects_use_git             => false,
        :init_repositories_on_create      => false,
        :delete_git_repositories          => true,
        :hierarchical_organisation        => true,
        :unique_repo_identifier           => false,

        # Download Revision Config
        :download_revision_enabled        => true,

        # Git Mailing List Config
        :gitolite_notify_by_default            => true,
        :gitolite_notify_global_prefix         => '[REDMINE]',
        :gitolite_notify_global_sender_address => 'redmine@example.com',
        :gitolite_notify_global_include        => [],
        :gitolite_notify_global_exclude        => [],

        # Sidekiq Config
        :gitolite_use_sidekiq                  => false,
        }
      }
    end

    include OpenProject::Plugins::ActsAsOpEngine

    register 'openproject-git_hosting',
      :author_url => 'https://github.com/oliverguenther/openproject_git_hosting',
      :requires_openproject => '>= 3.0.0',
      :settings => settings do

        project_module :repository do
          permission :create_repository_mirrors, { :repository_mirrors => :create }
          permission :view_repository_mirrors, { :repository_mirrors => :index }
          permission :edit_repository_mirrors, { :repository_mirrors => :edit }

          permission :create_repository_post_receive_urls, { :repository_post_receive_urls => :create }
          permission :view_repository_post_receive_urls, { :repository_post_receive_urls => :index }
          permission :edit_repository_post_receive_urls, { :repository_post_receive_urls => :edit }

          permission :create_deployment_keys, { :repository_deployment_credentials => :create }
          permission :view_deployment_keys, { :repository_deployment_credentials => :index }
          permission :edit_deployment_keys, { :repository_deployment_credentials => :edit }

          permission :create_repository_git_config_keys, { :repository_git_config_keys => :create }
          permission :view_repository_git_config_keys, { :repository_git_config_keys => :index }
          permission :edit_repository_git_config_keys, { :repository_git_config_keys => :edit }

          permission :create_repository_git_notifications, { :repository_git_notifications => :create }
          permission :view_repository_git_notifications, { :repository_git_notifications => :index }
          permission :edit_repository_git_notifications, { :repository_git_notifications => :edit } 
          permission :receive_git_notifications, { :gitolite_hooks => :post_receive } 

          permission :create_gitolite_ssh_key, { :my => :account }
          permission :download_git_revision, { :download_git_revision => :index }
        end


        menu :admin_menu,
          :openproject_git_hosting, 
          { :controller => 'settings', :action => 'plugin', :id => 'openproject_git_hosting' }, 
          :caption => :module_name

        menu :top_menu,
          :archived_repositories,
          { :controller => 'archived_repositories', :action => 'plugin' }, 
          :caption => :label_archived_repositories, 
          :after => :administration,
          :if => proc { User.current.logged? && User.current.admin? }
      end

    initializer 'git_hosting.patch_git_adapter' do
      require 'open_project/git_hosting/patches/git_adapter_patch'
    end
      #patches [:GitAdapter]
      # patches [:GitAdapter, :MyController, :RepositoryGit, :SettingsController,
      # :Issue, :Project, :Repository, :User, :Journal, :ProjectsController, :RolesController,
      # :UsersController, :Member, :RepositoriesController, :Setting, :UsersHelper]

  end
end
