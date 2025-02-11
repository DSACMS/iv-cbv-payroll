import { fetchToken, trackUserAction } from "../utilities/api";
import loadScript from 'load-script';
import { getDocumentLocale } from "../utilities/getDocumentLocale";

declare global {
    var Pinwheel: any;
}

export const createProvider = (providerName: string) => {
    switch(providerName) {
        default:
            return PinwheelIncomeDataAdapter;
    }
}
abstract class IncomeDataAdapter {
    successCallback?: Function;
    exitCallback?: Function;
    
    abstract open(responseType : string, id : string, name : string, isDefaultOption : boolean): void;
    abstract onEvent(eventName : string, eventPayload : any): void;
    abstract load();

    constructor(args : {
        onSuccess?: Function;
        onExit?: Function;
    } = { onSuccess: () => {}}) {
        this.successCallback = args.onSuccess;
        this.exitCallback = args.onExit;

        this.load();
    }

    async onExit(eventPayload: any) {
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