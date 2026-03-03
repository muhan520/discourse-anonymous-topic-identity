import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "anonymous-topic-identity-composer",

  initialize() {
    withPluginApi("1.15.0", (api) => {
      api.modifyClass("model:composer", {
        pluginId: "anonymous-topic-identity",

        anonymous_enabled: false,
        anonymous_alias: "",
      });

      api.serializeOnCreate("anonymous_enabled", "anonymous_enabled");
      api.serializeOnCreate("anonymous_alias", "anonymous_alias");
    });
  },
};
