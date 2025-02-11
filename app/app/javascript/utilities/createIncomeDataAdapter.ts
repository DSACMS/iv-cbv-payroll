import PinwheelIncomeDataAdapter from "../adapters/PinwheelIncomeDataAdapter";


export const createIncomeDataAdapter = (providerName: string) => {
    switch (providerName) {
        default:
            return PinwheelIncomeDataAdapter;
    }
};
