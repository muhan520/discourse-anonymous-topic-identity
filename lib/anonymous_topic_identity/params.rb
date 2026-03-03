# frozen_string_literal: true

module ::AnonymousTopicIdentity
  class Params
    BOOLEAN_TYPE = ActiveModel::Type::Boolean.new

    def self.anonymous_enabled?(opts)
      BOOLEAN_TYPE.cast(value(opts, :anonymous_enabled))
    end

    def self.anonymous_alias(opts)
      value(opts, :anonymous_alias).to_s.strip
    end

    def self.value(opts, key)
      return nil if opts.blank?

      opts[key] || opts[key.to_s]
    end
  end
end
