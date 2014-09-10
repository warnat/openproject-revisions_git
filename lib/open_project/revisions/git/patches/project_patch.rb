module OpenProject::Revisions::Git
  module Patches
    module ProjectPatch

      def self.included(base)
        base.class_eval do
          unloadable

          scope :active, -> { where "status = #{Project::STATUS_ACTIVE} OR status = #{Project::STATUS_ARCHIVED}" }
        end
      end
    end
  end
end

Project.send(:include, OpenProject::Revisions::Git::Patches::ProjectPatch)
