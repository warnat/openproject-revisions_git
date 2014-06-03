module OpenProject::GitHosting
  module Patches
    module ProjectPatch

      def self.included(base)
        base.class_eval do
          unloadable

          scope :active_or_archived, -> { where "status = #{Project::STATUS_ACTIVE} OR status = #{Project::STATUS_ARCHIVED}" }
        end
      end
    end
  end
end

Project.send(:include, OpenProject::GitHosting::Patches::ProjectPatch)
