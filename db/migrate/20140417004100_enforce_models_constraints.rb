require_relative "migration_utils/make_boolean"

class EnforceModelsConstraints < ActiveRecord::Migration

  extend MakeBoolean

  def self.up

    change_column :git_caches, :repo_identifier, :string, :null => false, :after => :id
    change_column :git_caches, :command,         :text,   :null => false
    change_column :git_caches, :command_output,  :binary, :null => false

    change_column :gitolite_public_keys, :user_id,    :integer, :null => false, :after => :id
    change_column :gitolite_public_keys, :key_type,   :integer, :null => false, :after => :user_id
    change_column :gitolite_public_keys, :title,      :string, :null => false
    change_column :gitolite_public_keys, :identifier, :string, :null => false
    change_column :gitolite_public_keys, :key,        :text,   :null => false
    change_column :gitolite_public_keys, :delete_when_unused, :boolean, :default => true, :after => :active

    # Postgres won't allow int to boolean type change without cast, thus we use a temp column instead
    change_column_to_boolean(GitolitePublicKey, :active, true)
    change_column_to_boolean(RepositoryDeploymentCredential, :active, true)
    change_column_to_boolean(RepositoryGitExtra, :git_daemon, false)
    change_column_to_boolean(RepositoryGitExtra, :git_notify, false)
    change_column_to_boolean(RepositoryMirror, :active, true)
    change_column_to_boolean(RepositoryPostReceiveUrl, :active, true)


    change_column :repository_deployment_credentials, :repository_id, :integer, :null => false
    change_column :repository_deployment_credentials, :gitolite_public_key_id, :integer, :null => false
    change_column :repository_deployment_credentials, :user_id, :integer, :null => false

    change_column :repository_git_config_keys, :repository_id, :integer, :null => false
    change_column :repository_git_config_keys, :key,           :string,  :null => false
    change_column :repository_git_config_keys, :value,         :string,  :null => false

    change_column :repository_git_extras, :repository_id, :integer, :null => false
    change_column :repository_git_extras, :key,           :string,  :null => false

    change_column :repository_git_notifications, :repository_id, :integer, :null => false

    change_column :repository_mirrors, :repository_id, :integer, :null => false, :after => :id
    change_column :repository_mirrors, :url,           :string,  :null => false, :after => :repository_id
    change_column :repository_mirrors, :push_mode,     :string,  :null => false
    remove_column :repository_mirrors, :created_at
    remove_column :repository_mirrors, :updated_at

    change_column :repository_post_receive_urls, :repository_id, :integer, :null => false, :after => :id
    change_column :repository_post_receive_urls, :url,           :string,  :null => false, :after => :repository_id
    change_column :repository_post_receive_urls, :mode,          :string,  :null => false, :after => :url
    remove_column :repository_post_receive_urls, :created_at
    remove_column :repository_post_receive_urls, :updated_at

  end

end
