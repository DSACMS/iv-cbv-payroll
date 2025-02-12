import { fetchToken, trackUserAction } from "../utilities/api";
import loadScript from 'load-script';
import { getDocumentLocale } from "../utilities/getDocumentLocale";
import { IncomeDataAdapter } from "./IncomeDataAdapter";

declare global {
    var Pinwheel: any;
}

export default class PinwheelIncomeDataAdapter extends IncomeDataAdapter {
    Pinwheel: any;

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

    async open() {
        const locale = getDocumentLocale();
        await trackUserAction("ApplicantSelectedEmployerOrPlatformItem", {
            item_type: this.requestData.responseType,
            item_id: this.requestData.id,
            item_name: this.requestData.name,
            is_default_option: this.requestData.isDefaultOption,
            provider_name: this.requestData.providerName,
            locale
        })

        const { token } = await fetchToken(this.requestData.responseType, this.requestData.id, locale);

        return this.Pinwheel.open({
            linkToken: token,
            onSuccess: this.onSuccess.bind(this),
            onExit: this.onExit.bind(this),
            onEvent: this.onEvent.bind(this),
        });
    }


    async onSuccess(eventPayload: {
        accountId: string;
        platformId: string;
    }) {
        await trackUserAction("PinwheelSuccess", {
            account_id: eventPayload.accountId,
            platform_id: eventPayload.platformId
        })
        if (this.successCallback) {
            this.successCallback(eventPayload.accountId);
        }
    }

    onEvent(eventName: string, eventPayload: any) {
        switch (eventName) {
            case "screen_transition":
                onScreenTransitionEvent(eventPayload.screenName);
                break;
            case 'login_attempt':
                trackUserAction("PinwheelAttemptLogin", {})
                break;
            case 'error':
                const { type, code, message } = eventPayload
                trackUserAction("PinwheelError", { type, code, message })
                break;
            case 'exit':
                trackUserAction("PinwheelCloseModal", {})
                break;
                
        }


        function onScreenTransitionEvent(screenName) {
            switch (screenName) {
                case "LOGIN":
                    trackUserAction("PinwheelShowLoginPage", {
                        screen_name: screenName,
                        employer_name: eventPayload.selectedEmployerName,
                        platform_name: eventPayload.selectedPlatformName
                    });
                    break;
                case "PROVIDER_CONFIRMATION":
                    trackUserAction("PinwheelShowProviderConfirmationPage", {});
                    break;
                case "SEARCH_DEFAULT":
                    trackUserAction("PinwheelShowDefaultProviderSearch", {});
                    break;
                case "EXIT_CONFIRMATION":
                    trackUserAction("PinwheelAttemptClose", {});
                    break;
            }
        }
    }
}