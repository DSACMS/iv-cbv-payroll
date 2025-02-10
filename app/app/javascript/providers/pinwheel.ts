import { loadPinwheel } from "../utilities/pinwheel";
import { trackUserAction } from "../utilities/api";

abstract class Provider {
    abstract load(): void;
    abstract init(): void;
    abstract onEvent(eventName : string, eventPayload : any): void;
}

export default class PinwheelProvider extends Provider {
    load() {
        loadPinwheel()
    }
    init() {

    }

    onSuccess(eventPayload: any, callback: Function) {
        const { accountId } = eventPayload
        this.userAccountIdTarget.value = accountId
        trackUserAction("PinwheelSuccess", {
            account_id: eventPayload.accountId,
            platform_id: eventPayload.platformId
        })
        this.formTarget.submit();

    }
    onEvent(eventName: string, eventPayload: any) {
        if (eventName === 'success') {
                    } else if (eventName === 'screen_transition') {
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