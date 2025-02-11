import { initializePinwheel } from "../utilities/pinwheel";
import { fetchToken, trackUserAction } from "../utilities/api";
import loadScript from 'load-script';
import { getDocumentLocale } from "../utilities/getDocumentLocale";

declare global {
    var Pinwheel: any;
}

abstract class ProviderWrapper {
    abstract successCallback?: Function;

    abstract open(responseType : string, id : string, name : string, isDefaultOption : boolean): void;
    abstract onEvent(eventName : string, eventPayload : any): void;
}

export default class PinwheelProviderWrapper extends ProviderWrapper {
    Pinwheel: any;
    successCallback?: Function;

    constructor(args : {
        onSuccess?: Function;
    } = { onSuccess: () => {}}) {
        super();
        this.successCallback = args.onSuccess;

        this.load();
    }

    async load() {
        this.Pinwheel = await new Promise((resolve, reject) => {
            loadScript('https://cdn.getpinwheel.com/pinwheel-v3.0.js', (err, script) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(Pinwheel);
                }
            });
        })
    }

    async open(responseType, id, name, isDefaultOption) {
        const locale = getDocumentLocale();
        await trackUserAction("ApplicantSelectedEmployerOrPlatformItem", {
            item_type: responseType,
            item_id: id,
            item_name: name,
            is_default_option: isDefaultOption,
            locale
        })

        const { token } = await fetchToken(responseType, id, locale);

        return this.Pinwheel.open({
            token,
            onSuccess: this.onSuccess.bind(this),
            onEvent: this.onEvent.bind(this),
            //onExit: this.reenableButtons.bind(this),
        });
    }

    async onSuccess(eventPayload: {
        accountId: string;
        platformId: string;
    }) {
        //    this.userAccountIdTarget.value = accountId
        //    this.formTarget.submit();
        await trackUserAction("PinwheelSuccess", {
            account_id: eventPayload.accountId,
            platform_id: eventPayload.platformId
        })
        if (this.successCallback) {
            this.successCallback();
        }
    }

    onEvent(eventName: string, eventPayload: any) {
        if (eventName === 'screen_transition') {
            const { screenName } = eventPayload

            switch (screenName) {
                case "LOGIN":
                    trackUserAction("PinwheelShowLoginPage", {
                        screen_name: screenName,
                        employer_name: eventPayload.selectedEmployerName,
                        platform_name: eventPayload.selectedPlatformName
                    })
                    break
                case "PROVIDER_CONFIRMATION":
                    trackUserAction("PinwheelShowProviderConfirmationPage", {})
                    break
                case "SEARCH_DEFAULT":
                    trackUserAction("PinwheelShowDefaultProviderSearch", {})
                    break
                case "EXIT_CONFIRMATION":
                    trackUserAction("PinwheelAttemptClose", {})
                    break
            }
        } else if (eventName === 'login_attempt') {
            trackUserAction("PinwheelAttemptLogin", {})
        } else if (eventName === 'error') {
            const { type, code, message } = eventPayload
            trackUserAction("PinwheelError", { type, code, message })
        } else if (eventName === 'exit') {
            trackUserAction("PinwheelCloseModal", {})
        }

    }
}