import PinwheelModalAdapter from "@js/adapters/PinwheelModalAdapter.js";
import ArgyleModalAdapter from "@js/adapters/ArgyleModalAdapter.js";

export const createModalAdapter = (providerName: string) => {
  switch (providerName) {
    case "argyle":
      return new ArgyleModalAdapter();
    case "pinwheel":
      return new PinwheelModalAdapter();
    default:
      console.error("Unknown createModalAdapter provider:", providerName);
  }
};
