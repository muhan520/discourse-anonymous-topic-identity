# frozen_string_literal: true

module ::AnonymousTopicIdentity
  class AliasValidator
    ALIAS_REGEX = /\A[\p{Han}\p{L}\p{N}_-]+\z/u

    attr_reader :error_message

    def initialize(alias_name)
      @alias_name = alias_name.to_s.strip
      @error_message = nil
    end

    def valid?
      if @alias_name.blank?
        @error_message = I18n.t("anonymous_topic_identity.errors.alias_required")
        return false
      end

      min = SiteSetting.anonymous_topic_identity_alias_min_length.to_i
      max = SiteSetting.anonymous_topic_identity_alias_max_length.to_i
      length = @alias_name.length

      if length < min
        @error_message = I18n.t("anonymous_topic_identity.errors.alias_too_short", min: min)
        return false
      end

      if length > max
        @error_message = I18n.t("anonymous_topic_identity.errors.alias_too_long", max: max)
        return false
      end

      unless @alias_name.match?(ALIAS_REGEX)
        @error_message = I18n.t("anonymous_topic_identity.errors.alias_invalid_chars")
        return false
      end

      if denied?(@alias_name)
        @error_message = I18n.t("anonymous_topic_identity.errors.alias_blocked")
        return false
      end

      true
    end

    private

    def denied?(value)
      denylist.include?(value.downcase)
    end

    def denylist
      @denylist ||= begin
        all_items = []
        all_items.concat(split_words(SiteSetting.respond_to?(:reserved_usernames) ? SiteSetting.reserved_usernames : nil))
        all_items.concat(split_words(SiteSetting.anonymous_topic_identity_extra_denylist))
        all_items.map! { |word| word.downcase.strip }
        all_items.reject!(&:blank?)
        all_items.uniq
      end
    end

    def split_words(raw)
      return [] if raw.blank?

      Array(raw).flat_map { |item| item.to_s.split(/[\n,|]/) }
    end
  end
end
