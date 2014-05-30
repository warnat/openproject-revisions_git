module OpenProject::GitHosting
  module Patches
    module UsersControllerPatch

      include GitolitePublicKeysHelper

      def self.included(base)
        base.class_eval do
          unloadable

          include InstanceMethods

          alias_method_chain :edit,   :git_hosting
        end
      end


      module InstanceMethods

        def edit_with_git_hosting(&block)
          # Set public key values for view
          set_public_key_values

          # Previous routine
          edit_without_git_hosting(&block)
        end


        private


        # Add in values for viewing public keys:
        def set_public_key_values
          set_user_keys
        end
      end
    end
  end
end

UsersController.send(:include, OpenProject::GitHosting::Patches::UsersControllerPatch)
