# frozen_string_literal: true

module ::AnonymousTopicIdentity
  module PostCreatorExtension
    def create
      return nil unless PreflightValidator.validate!(user: @user, opts: @opts, errors: errors)

      super
    end
  end
end
