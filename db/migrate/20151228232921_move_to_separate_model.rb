class MoveToSeparateModel < ActiveRecord::Migration
  def self.up
    Repository::Git.update_all(type: 'Repository::Gitolite',
                               scm_type: 'managed')

  end

  def self.down
    Repository::Gitolite.update_all(type: 'Repository::Git',
                                    scm_type: 'local')

  end
end
