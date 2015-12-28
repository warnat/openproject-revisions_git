module OpenProject::Revisions::Git
  module Patches
    module SettingsControllerPatch
      def self.included(base)
        base.class_eval do
          unloadable

          helper :revisions_git
        end
      end
      
      module InstanceMethods
        def install_gitolite_hooks
          @plugin = Redmine::Plugin.find(params[:id])
          return render_404 unless @plugin.id == :openproject_revisions_git
          @gitolite_checks = OpenProject::Revisions::Git::Config.install_hooks!
        end
      end
      
    end
  end
end

SettingsController.send(:include, OpenProject::Revisions::Git::Patches::SettingsControllerPatch)
