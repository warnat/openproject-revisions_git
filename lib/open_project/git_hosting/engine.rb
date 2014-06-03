module OpenProject::GitHosting
  class Engine < ::Rails::Engine
    engine_name :openproject_git_hosting


    def self.settings 
      { :partial => 'settings/openproject_git_hosting',
        :default => {
        # Gitolite SSH Config
        :gitolite_user                  => 'git',
        :gitolite_server_port           => '22',
        :gitolite_ssh_private_key       => File.join(Dir.home, '.ssh', 'id_rsa').to_s,
        :gitolite_ssh_public_key        => File.join(Dir.home, '.ssh', 'id_rsa.pub').to_s,

        # Gitolite Storage Config
        :gitolite_global_storage_dir    => File.join(Dir.home, 'repositories'),
        :gitolite_redmine_storage_dir   => '',
        :gitolite_recycle_bin_dir       => 'recycle_bin/',

        # Gitolite Config File
        :gitolite_admin_dir                    => File.join(Dir.home, 'gitolite-admin'),
        :gitolite_identifier_prefix            => 'openproject_',

        # Gitolite Global Config
        :gitolite_temp_dir                     => Dir.mktmpdir('gitolite_tmp').to_s,
        :gitolite_scripts_dir                  => File.join(Dir.home, 'bin'),
        :gitolite_timeout                      => 10,
        :gitolite_recycle_bin_expiration_time  => 24.0,
        :gitolite_log_level                    => 'info',
        :gitolite_log_split                    => false,
        :git_config_username                   => 'OpenProject Git Hosting',
        :git_config_email                      => 'openproject@localhost',

        # Gitolite Hooks Config
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

        # Download Revision Config
        :download_revision_enabled        => true,

        # Git Mailing List Config
        :gitolite_notify_by_default            => true,
        :gitolite_notify_global_prefix         => '[REDMINE]',
        :gitolite_notify_global_sender_address => 'redmine@example.com',
        :gitolite_notify_global_include        => [],
        :gitolite_notify_global_exclude        => [],

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

          permission :create_gitolite_ssh_key, { :my => :account }
          permission :download_git_revision, { :download_git_revision => :index }
        end


        menu :top_menu,
          :archived_repositories,
          { :controller => 'archived_repositories', :action => 'plugin' },
          :caption => :label_archived_repositories,
          :after => :administration,
          :if => proc { User.current.logged? && User.current.admin? }

        menu :my_menu,
          :public_keys,
          { :controller => 'my_public_keys', :action => 'index'},
          :html => { :class => 'icon2 icon-locked-folder' },
          :caption => :label_public_keys

      end

    # Reload patches for development
    # initializer 'git_hosting.patches' do
    ActionDispatch::Callbacks.to_prepare do
      require_dependency 'open_project/git_hosting/patches/git_adapter_patch'
      require_dependency 'open_project/git_hosting/patches/repository_git_patch'
      Redmine::Scm::Adapters::GitAdapter.send(:include, OpenProject::GitHosting::Patches::GitAdapterPatch)
      Repository::Git.send(:include, OpenProject::GitHosting::Patches::RepositoryGitPatch)

      # TODO remove
      # require 'open_project/git_hosting/patches/member_patch'
      # require 'open_project/git_hosting/patches/my_controller_patch'
      # require 'open_project/git_hosting/patches/project_patch'
      # require 'open_project/git_hosting/patches/projects_controller_patch'
      # require 'open_project/git_hosting/patches/repositories_controller_patch'
      # require 'open_project/git_hosting/patches/repositories_helper_patch'
      # require 'open_project/git_hosting/patches/repository_patch'
      # require 'open_project/git_hosting/patches/roles_controller_patch'
      # require 'open_project/git_hosting/patches/setting_patch'
      # require 'open_project/git_hosting/patches/settings_controller_patch'
      # require 'open_project/git_hosting/patches/user_patch'
      # require 'open_project/git_hosting/patches/users_controller_patch'
      # require 'open_project/git_hosting/patches/users_helper_patch'
    end

    initializer 'git_hosting.hooks' do
      require_relative 'hooks'
    end


      patches [
        :Project, :Repository, :User, :Setting, :Member,
        :ProjectsController, :RolesController, :RepositoriesController,
        :SettingsController, :UsersController, :MyController,
        :RepositoriesHelper, :UsersHelper
      ]

  end
end
