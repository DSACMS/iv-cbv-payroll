import type { RequestData, ModalAdapterArgs } from "./ModalAdapter.types.ts"

export abstract class ModalAdapter {
  requestData?: RequestData
  successCallback?: Function
  exitCallback?: Function
  modalSdk: Argyle | Pinwheel

  abstract open(): void

  constructor(modalSdk: Argyle | Pinwheel) {
    this.modalSdk = modalSdk
  }

  init(args: ModalAdapterArgs) {
    if (args.onSuccess) {
      this.successCallback = args.onSuccess
    }

    if (args.onExit) {
      this.exitCallback = args.onExit
    }
    if (args.requestData) {
      this.requestData = args.requestData
    }
  }

  async onExit(eventPayload: any = {}) {
    if (this.exitCallback) {
      this.exitCallback()
    }
  }

  async onSuccess(eventPayload: any) {
    if (this.successCallback) {
      this.successCallback()
    }
  }
}
