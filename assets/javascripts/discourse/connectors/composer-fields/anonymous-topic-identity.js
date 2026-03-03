import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import I18n from "I18n";

const ALIAS_REGEX = /^[\p{L}\p{N}_-]+$/u;

export default class AnonymousTopicIdentityComposerFields extends Component {
  @service siteSettings;

  get composer() {
    return this.args.outletArgs?.composer;
  }

  get enabled() {
    return Boolean(this.composer?.model?.anonymous_enabled);
  }

  get alias() {
    return this.composer?.model?.anonymous_alias || "";
  }

  get codePlaceholder() {
    const length = this.siteSettings.anonymous_topic_identity_code_length || 7;
    return "x".repeat(length);
  }

  get previewAlias() {
    const alias = (this.alias || "").trim();
    return alias.length > 0 ? alias : "...";
  }

  get minLength() {
    return this.siteSettings.anonymous_topic_identity_alias_min_length || 2;
  }

  get maxLength() {
    return this.siteSettings.anonymous_topic_identity_alias_max_length || 20;
  }

  get aliasLength() {
    return this.alias.trim().length;
  }

  get aliasTooShort() {
    return this.aliasLength > 0 && this.aliasLength < this.minLength;
  }

  get aliasTooLong() {
    return this.aliasLength > this.maxLength;
  }

  get aliasInvalidChars() {
    return this.aliasLength > 0 && !ALIAS_REGEX.test(this.alias.trim());
  }

  get validationMessage() {
    if (this.aliasLength === 0) {
      return I18n.t("anonymous_topic_identity.composer.validation_required");
    }

    if (this.aliasTooShort) {
      return I18n.t("anonymous_topic_identity.composer.validation_too_short", {
        min: this.minLength,
      });
    }

    if (this.aliasTooLong) {
      return I18n.t("anonymous_topic_identity.composer.validation_too_long", {
        max: this.maxLength,
      });
    }

    if (this.aliasInvalidChars) {
      return I18n.t("anonymous_topic_identity.composer.validation_invalid_chars");
    }

    return I18n.t("anonymous_topic_identity.composer.validation_ok");
  }

  get validationClass() {
    return this.aliasLength === 0 ||
      this.aliasTooShort ||
      this.aliasTooLong ||
      this.aliasInvalidChars
      ? "is-invalid"
      : "is-valid";
  }

  @action
  toggleEnabled(event) {
    if (!this.composer?.model) {
      return;
    }

    this.composer.model.set("anonymous_enabled", event.target.checked);
    if (!event.target.checked) {
      this.composer.model.set("anonymous_alias", "");
    }
  }

  @action
  updateAlias(event) {
    if (!this.composer?.model) {
      return;
    }

    this.composer.model.set("anonymous_alias", event.target.value);
  }
}
