# frozen_string_literal: true

require "openssl"

module ::AnonymousTopicIdentity
  class AntiCodeGenerator
    MIN_CODE_LENGTH = 6
    MAX_CODE_LENGTH = 12

    def self.generate(user_id:, topic_id:)
      digest = OpenSSL::HMAC.digest(
        "SHA256",
        secret_key,
        "#{user_id}:#{topic_id}"
      )

      length = SiteSetting.anonymous_topic_identity_code_length.to_i.clamp(MIN_CODE_LENGTH, MAX_CODE_LENGTH)
      base36 = digest.unpack1("H*").to_i(16).to_s(36)

      base36[0, length].ljust(length, "0")
    end

    def self.secret_key
      configured_key = SiteSetting.anonymous_topic_identity_secret_key.to_s.strip
      return configured_key if configured_key.present?

      Rails.application.secret_key_base
    end

    private_class_method :secret_key
  end
end
