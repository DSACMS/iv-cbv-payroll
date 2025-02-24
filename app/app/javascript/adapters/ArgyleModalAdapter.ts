import { trackUserAction } from "../utilities/api.js";
import { fetchInternal } from '../utilities/fetchInternal.js';
import loadScript from 'load-script';
import { getDocumentLocale } from "../utilities/getDocumentLocale.js";
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
        sandbox: true, 
      }).open();
    }
  }

  async onSuccess(eventPayload: LinkResult) {
    await trackUserAction("ArgyleSuccess", {
      account_id: eventPayload.accountId,
      platform_id: eventPayload.platformId
    });

    if (this.successCallback) {
      this.successCallback(eventPayload.accountId);
    }
  }

  onEvent(eventName: string, eventPayload: any) {
  }
}
