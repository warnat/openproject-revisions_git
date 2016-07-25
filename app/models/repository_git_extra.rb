require 'digest/sha1'

class RepositoryGitExtra < ActiveRecord::Base
  belongs_to :repository, class_name: 'Repository', foreign_key: 'repository_id'

  validates_associated :repository

  after_initialize :set_values

  def set_values_for_existing_repo
    if !repository.nil?
      #When the default branch is null, it means that the proper configuration was not made for this repository when it was created
      if default_branch.nil?
        generate
        setup_defaults
      end
    end
  end

  def validate_encoded_time(clear_time, encoded_time)
    valid = false
    begin
      cur_time_seconds = Time.new.utc.to_i
      test_time_seconds = clear_time.to_i
      if cur_time_seconds - test_time_seconds < 5*60
        key = read_attribute(:key)
        test_encoded = Digest::SHA1.hexdigest(clear_time.to_s + key.to_s)
        if test_encoded.to_s == encoded_time.to_s
          valid = true
        end
      end
    rescue Exception=>e
    end
    valid
  end

  private

  def set_values
    if repository.nil?
      generate
      setup_defaults
    end
  end

  def generate
    if key.nil?
      self.key = (0...64 + rand(64)).map { 65.+(rand(25)).chr }.join
    end
  end

  def setup_defaults
    self.git_http = Setting.plugin_openproject_revisions_git[:gitolite_http_by_default]
    self.git_daemon = Setting.plugin_openproject_revisions_git[:gitolite_daemon_by_default]
    self.git_notify = Setting.plugin_openproject_revisions_git[:gitolite_notify_by_default]
    self.default_branch = 'master'
  end
end
