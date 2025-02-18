import PinwheelModalAdapter from "../adapters/PinwheelModalAdapter";


export const createModalAdapter = (providerName: string) => {
    switch (providerName) {
        default:
            return PinwheelModalAdapter;
    }
};
