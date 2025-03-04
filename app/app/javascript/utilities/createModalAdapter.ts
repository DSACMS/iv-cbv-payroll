import PinwheelModalAdapter from "../adapters/PinwheelModalAdapter.js";

export const createModalAdapter = (providerName: string) => {
  switch (providerName) {
    default:
      return new PinwheelModalAdapter();
  }
};
