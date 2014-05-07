module OpenProject::GitHosting
  module Patches
    module SettingsControllerPatch

      def self.included(base)
        base.class_eval do
          unloadable

          helper  :git_hosting
        end
      end

    end
  end
end

unless SettingsController.included_modules.include?(OpenProject::GitHosting::Patches::SettingsControllerPatch)
  SettingsController.send(:include, OpenProject::GitHosting::Patches::SettingsControllerPatch)
end
