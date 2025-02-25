import { trackUserAction } from "@js/utilities/api.js";
import { fetchInternal } from '@js/utilities/fetchInternal.js';
import loadScript from 'load-script';
import { getDocumentLocale } from "@js/utilities/getDocumentLocale.js";
import { ModalAdapter } from "./ModalAdapter.js";

const ARGYLE_TOKENS_GENERATE = '/api/argyle/tokens';

const fetchToken = () => {
  return fetchInternal(ARGYLE_TOKENS_GENERATE, {
    method: 'post',
  })
};

export default class ArgyleModalAdapter extends ModalAdapter {
  Argyle: Argyle;

  async load() {
    this.Argyle = await new Promise((resolve, reject) => {
      loadScript('https://plugin.argyle.com/argyle.web.v5.js', (err, script) => {
        if (err) {
          reject(err);
        } else {
          resolve(Argyle);
        }
      });
    })
  }

  async open() {
    const locale = getDocumentLocale();

    if (this.requestData) {
      await trackUserAction("ApplicantSelectedEmployerOrPlatformItem", {
        item_type: this.requestData.responseType,
        item_id: this.requestData.id,
        item_name: this.requestData.name,
        is_default_option: this.requestData.isDefaultOption,
        provider_name: this.requestData.providerName,
        locale
      })

      const { user } = await fetchToken();
      return this.Argyle.create({
        userToken: user.user_token,
        items: [this.requestData.id],
        onAccountConnected: this.onSuccess.bind(this),
        onTokenExpired: this.onTokenExpired.bind(this),
        onAccountCreated: async (payload) => { await trackUserAction("ArgyleAccountCreated", payload) },
        onAccountError: async (payload) => { await trackUserAction("ArgyleAccountError", payload) },
        onAccountRemoved: async (payload) => { await trackUserAction("ArgyleAccountRemoved", payload) },
        onClose: async () => { await trackUserAction("ArgyleCloseModal") },
        onError: async(err : LinkError) => { await trackUserAction("ArgyleError", err)},
        sandbox: true, 
      }).open();
    }
  }

  async onSuccess(eventPayload: ArgyleAccountData) {
    await trackUserAction("ArgyleSuccess", {
      account_id: eventPayload.accountId,
      user_id: eventPayload.userId,
      item_id: eventPayload.itemId,
    });

    if (this.successCallback) {
      this.successCallback(eventPayload.accountId);
    }
  }

  async onTokenExpired(updateToken : Function) {
      await trackUserAction("ArgyleTokenExpired")
      const { user } = await fetchToken();
      updateToken(user.user_token)
  }
  onEvent(eventName: string, eventPayload: any) {
  }
}
