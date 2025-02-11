export abstract class IncomeDataAdapter {
    successCallback?: Function;
    exitCallback?: Function;

    abstract load();
    abstract open(responseType: string, id: string, name: string, isDefaultOption: boolean): void;
    abstract onEvent(eventName: string, eventPayload: any): void;

    constructor(args: {
        onSuccess?: Function;
        onExit?: Function;
    } = { onSuccess: () => { } }) {
        this.successCallback = args.onSuccess;
        this.exitCallback = args.onExit;

        this.load();
    }

    async onExit(eventPayload: any) {
        if (this.exitCallback) {
            this.exitCallback();
        }
    }

    async onSuccess(eventPayload: any) {
        if (this.successCallback) {
            this.successCallback();
        }
    }
}
