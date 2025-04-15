import { trackUserAction, fetchArgyleToken } from "@js/utilities/api.js"
import { getDocumentLocale } from "@js/utilities/getDocumentLocale.js"
import { ModalAdapter } from "./ModalAdapter.js"

export default class ArgyleModalAdapter extends ModalAdapter {
  Argyle: Argyle

  async open() {
    const locale = getDocumentLocale()

    if (this.requestData) {
      await trackUserAction("ApplicantSelectedEmployerOrPlatformItem", {
        item_type: this.requestData.responseType,
        item_id: this.requestData.id,
        item_name: this.requestData.name,
        is_default_option: this.requestData.isDefaultOption,
        provider_name: this.requestData.providerName,
        locale,
      })

      const { user, isSandbox } = await fetchArgyleToken()
      return Argyle.create({
        userToken: user.user_token,
        items: [this.requestData.id],
        onAccountConnected: this.onSuccess.bind(this),
        onTokenExpired: this.onTokenExpired.bind(this),
        onAccountCreated: async (payload) => {
          await trackUserAction("ArgyleAccountCreated")
        },
        onAccountError: async (payload) => {
          await trackUserAction("ArgyleAccountError")
        },
        onAccountRemoved: async (payload) => {
          await trackUserAction("ArgyleAccountRemoved")
        },
        onUIEvent: async (payload) => {
          await this.onUIEvent(payload)
        },
        onClose: this.onClose.bind(this),
        onError: this.onError.bind(this),
        sandbox: isSandbox,
      }).open()
    } else {
      // TODO this should throw an error, which should be caught by a document.onerror handler to show the user a crash message.
      await trackUserAction("ModalAdapterError", {
        message: "Missing requestData from init() function",
      })
      this.onExit()
    }
  }

  async onError(err: LinkError) {
    await trackUserAction("ArgyleError", err)
    this.onExit()
  }

  async onClose() {
    await trackUserAction("ArgyleCloseModal")
    await this.onExit()
  }

  async onUIEvent(payload: ArgyeUIEvent) {
    switch (payload.name) {
      case "search - opened":
        await trackUserAction("ApplicantViewedArgyleDefaultProviderSearch")
        break
      case "login - opened":
        switch (payload.properties.errorCode) {
          case "auth_required":
            await trackUserAction("ApplicantEncounteredArgyleAuthRequiredLoginError")
            break
          case "connection_unavailable":
            await trackUserAction("ApplicantEncounteredArgyleConnectionUnavailableLoginError")
            break
          case "expired_credentials":
            await trackUserAction("ApplicantEncounteredArgyleExpiredCredentialsLoginError")
            break
          case "invalid_auth":
            await trackUserAction("ApplicantEncounteredArgyleInvalidAuthLoginError")
            break
          case "invalid_credentials":
            await trackUserAction("ApplicantEncounteredArgyleInvalidCredentialsLoginError")
            break
          case "mfa_cancelled_by_the_user":
            await trackUserAction("ApplicantEncounteredArgyleMfaCanceledLoginError")
            break
          default:
            await trackUserAction("ApplicantViewedArgyleLoginPage")
            break
        }
        break
      case "search - link item selected":
        await trackUserAction("ApplicantViewedArgyleProviderConfirmation")
        break
      case "search - term updated":
        await trackUserAction("ApplicantUpdatedArgyleSearchTerm", {
          term: payload.properties.term,
          tab: payload.properties.tab,
        })
        break
      case "login - form submitted":
        await trackUserAction("ApplicantAttemptedArgyleLogin")
        break
      case "mfa - opened":
        await trackUserAction("ApplicantAccessedArgyleModalMFAScreen")
        break
      case "link - closed":
        await trackUserAction("ApplicantAttemptedClosingArgyleModal")
        break
      default:
        break
    }
  }

  async onSuccess(eventPayload: ArgyleAccountData) {
    await trackUserAction("ArgyleSuccess", {
      account_id: eventPayload.accountId,
      user_id: eventPayload.userId,
      item_id: eventPayload.itemId,
    })

    if (this.successCallback) {
      setTimeout(() => {
        // TODO[FFS-2675]: Remove this artifical delay. It current exists to
        // allow time for Argyle to send us the `accounts.connected` webhook.
        this.successCallback(eventPayload.accountId)
      }, 1000)
    }
  }

  async onTokenExpired(updateToken: Function) {
    await trackUserAction("ArgyleTokenExpired")
    const { user } = await fetchArgyleToken()
    updateToken(user.user_token)
  }
}
