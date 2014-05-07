module OpenProject::GitHosting
  module Patches
    module ProjectPatch

      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          unloadable

          scope :active_or_archived, -> { where "status = #{Project::STATUS_ACTIVE} OR status = #{Project::STATUS_ARCHIVED}" }
        end
      end


      module InstanceMethods

        # Find all repositories owned by project which are Repository::Git
        def gitolite_repos
          repositories.select{|x| x.is_a?(Repository::Git)}
        end

        # Return first repo with a blank identifier (should be only one!)
        def repo_blank_ident
          Repository.find_by_project_id(id, :conditions => ["identifier = '' or identifier is null"])
        end

        private

      end

    end
  end
end

unless Project.included_modules.include?(OpenProject::GitHosting::Patches::ProjectPatch)
  Project.send(:include, OpenProject::GitHosting::Patches::ProjectPatch)
end
