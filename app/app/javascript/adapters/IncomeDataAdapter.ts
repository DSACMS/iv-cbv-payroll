
interface IncomeDataAdapterArgs {
    requestData: RequestData,
    onSuccess?: Function;
    onExit?: Function;
}

interface RequestData {
    responseType: string;
    id: string;
    isDefaultOption: boolean;
    provider: string;
    name: string;
}
export abstract class IncomeDataAdapter {
    requestData: RequestData;
    successCallback?: Function;
    exitCallback?: Function;

    abstract load();
    abstract open(): void;
    abstract onEvent(eventName: string, eventPayload: any): void;

    constructor(args: IncomeDataAdapterArgs) {
        this.successCallback = args.onSuccess;
        this.exitCallback = args.onExit;
        this.requestData = args.requestData;

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
