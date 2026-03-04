import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "anonymous-topic-identity-topic-map",

  initialize() {
    withPluginApi("1.15.0", (api) => {
      api.registerValueTransformer("post-show-topic-map", () => false);

      api.modifyClass(
        "controller:topic",
        (Superclass) =>
          class extends Superclass {
            get showBottomTopicMap() {
              return false;
            }
          }
      );
    });
  },
};
