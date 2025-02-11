import PinwheelIncomeDataAdapter from "./PinwheelIncomeDataAdapter";


export const createIncomeDataAdapter = (providerName: string) => {
    switch (providerName) {
        default:
            return PinwheelIncomeDataAdapter;
    }
};
