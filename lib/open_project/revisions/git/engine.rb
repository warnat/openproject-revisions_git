require 'socket'
module OpenProject::Revisions::Git
  GITHUB_ISSUE = 'https://github.com/oliverguenther/openproject-revisions_git/issues'

  class Engine < ::Rails::Engine
    engine_name :openproject_revisions_git

    def self.default_hostname
      Socket.gethostname || 'localhost'
    rescue
      nil
    end

    def self.settings
      {
        partial: 'settings/openproject_revisions_git',
        default:
        {
          # Gitolite SSH Config
          gitolite_user: 'git',
          gitolite_server_port: '22',
          gitolite_ssh_private_key: File.join(Dir.home, '.ssh', 'id_rsa').to_s,
          gitolite_ssh_public_key: File.join(Dir.home, '.ssh', 'id_rsa.pub').to_s,

          # Gitolite Storage Config
          # deprecated
          gitolite_global_storage_dir: 'repositories',
          # Full path
          gitolite_global_storage_path: '/home/git/repositories',

          # Gitolite Config File
          gitolite_admin_dir: File.join(Dir.home, 'gitolite-admin'),

          # Gitolite Global Config
          gitolite_scripts_dir: File.join(Dir.home, 'bin'),
          gitolite_timeout: 10,
          gitolite_log_level: 'info',
          gitolite_log_split: false,
          git_config_username: 'OpenProject Revisions(Git)',
          git_config_email: 'openproject@localhost',

          # Gitolite Access Config
          ssh_server_domain: default_hostname,
          https_server_domain: default_hostname,
          gitolite_daemon_by_default: false,
          gitolite_http_by_default: 1,

          # Redmine Config
          init_repositories_on_create: false,

          # Delayed jobs
          use_delayed_jobs: false,
        }
      }
    end

    include OpenProject::Plugins::ActsAsOpEngine

    register(
      'openproject-revisions_git',
      author_url: 'https://github.com/oliverguenther/openproject_revisions_git',
      requires_openproject: '>= 3.0.0',
      settings: settings
    ) do
      project_module :repository do
        permission :create_repository_git_config_keys, repository_git_config_keys: :create
        permission :view_repository_git_config_keys, repository_git_config_keys: :index
        permission :edit_repository_git_config_keys, repository_git_config_keys: :edit

        permission :create_gitolite_ssh_key, my: :account
        permission :create_deployment_keys, my: :account
        permission :create_repository_deployment_credentials, my: :account
        permission :create_repository_post_receive_urls, my: :account
        permission :create_repository_mirrors, my: :account
        #Next line is not valid because there is not controller "download_git_revision"
        #permission :download_git_revision, download_git_revision: :index
      end

      # Public Keys under user account
      menu(
        :my_menu,
        :public_keys,
        { controller: 'my_public_keys', action: 'index' },
        html: { class: 'icon2 icon-folder-locked' },
        caption: :label_public_keys
      )

      #Extends "project_menu": add the "manage_git_repositories" tab (menu option) to the project menu
      #It only shows the tab (menu option) if the repository is a Git repository with the "if" sentence
      menu(
        :project_menu,
        :manage_git_repositories,
        { controller: 'manage_git_repositories', action: 'index' },
        caption: 'Manage Git repository',
        param: :project_id,
        parent: :repository,
        if: Proc.new { |p| p.repository && p.repository.is_a?(Repository::Git) },
        html: { class: 'icon2 icon-locked-folder' }
      )
        
      #To show the menu as a submenu within another module we need to enable the permissions:
      #We declare one project based permission: view for manage git repositories.
      #The permission is not public (with ", :public => true"), so we have to anable it to every role we want in the settings of OpenProject
      #We wrap the permissions declaration inside a call to "project_module" to create a module, now we have to enable the module "repository" (already existing) for the projects we want to use it in
      #In other words, "manage_git_repository" will be enabled if "repository" is enabled
      project_module :repository do
        #permission :view_manage_git_repositories, manage_git_repositories: :index #This seems not to work with ", :public => true"
        permission :manage_git_repositories, { :manage_git_repositories => [:index] }, :public => true #MabEntwickeltSich: Public for testing
        #Template for one general permission that may involve many controllers and actions: 
        #permission :permission_name, {:controller => [:action, :action, ...]}, :public => true
        permission :repository_deployment_credentials, { :repository_deployment_credentials => [:index] }, :public => true #MabEntwickeltSich: Public for testing
        permission :repository_post_receive_urls, { :repository_post_receive_urls => [:index] }, :public => true #MabEntwickeltSich: Public for testing
        permission :repository_mirrors, { :repository_mirrors => [:index] }, :public => true #MabEntwickeltSich: Public for testing
      end  

    end

    #The patch for "repository" should be in the beginning, otherwise it will not work.
    config.to_prepare do
      # act_as_op_engine doesn't like the hierarchical plugin/engine name :)
      [
        :user, :setting,
        :users_controller, :my_controller,
        :users_helper,
      ].each do |sym|
        require_dependency "open_project/revisions/git/patches/#{sym}_patch"
      end
    end

    initializer 'revisions_git.scm_vendor' do
      require 'open_project/scm/manager'
      OpenProject::Scm::Manager.add :gitolite
    end

    initializer 'revisions_git.configuration' do
      config = Setting.repository_checkout_data.presence || {}
      Setting.repository_checkout_data = config.merge('gitolite' => { 'enabled' => 1 })
    end

    initializer 'revisons_git.precompile_assets' do
      Rails.application.config.assets.precompile += %w(revisions_git/revisions_git.css)
    end

    initializer 'revisions_git.notification_listeners' do
      %i(member_updated
         member_removed
         roles_changed
         project_deletion_imminent
         project_updated).each do |sym|
        ::OpenProject::Notifications.subscribe(sym.to_s, &NotificationHandlers.method(sym))
      end
    end
  end
end
