module OpenProject::GitHosting
  module Patches
    module MemberPatch

      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods

          after_commit  :update_member
        end
      end

      module InstanceMethods

        private

        def update_member
          OpenProject::GitHosting::GitHosting.logger.info("Membership changes on project '#{self.project}', update!")
          OpenProject::GitHosting::GitoliteWrapper.update(:update_repository, self.project.repository)
        end

      end

    end
  end
end

Member.send(:include, OpenProject::GitHosting::Patches::MemberPatch)
