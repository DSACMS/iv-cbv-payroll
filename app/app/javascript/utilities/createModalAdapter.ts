import PinwheelModalAdapter from "@js/adapters/PinwheelModalAdapter.js"
import ArgyleModalAdapter from "@js/adapters/ArgyleModalAdapter.js"
import E2ECallbackRecorder from "./E2eCallbackRecorder.js"

export const createModalAdapter = (providerName: string) => {
  const enableCallbackRecording = E2ECallbackRecorder.enabled()

  switch (providerName) {
    case "argyle":
      return new ArgyleModalAdapter(enableCallbackRecording ? E2ECallbackRecorder.Argyle : Argyle)
    case "pinwheel":
      return new PinwheelModalAdapter(
        enableCallbackRecording ? E2ECallbackRecorder.Pinwheel : Pinwheel
      )
    default:
      console.error("Unknown createModalAdapter provider:", providerName)
  }
}
