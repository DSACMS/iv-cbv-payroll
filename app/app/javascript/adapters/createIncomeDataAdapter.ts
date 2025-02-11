import PinwheelIncomeDataAdapter from "./pinwheel";


export const createIncomeDataAdapter = (providerName: string) => {
    switch (providerName) {
        default:
            return PinwheelIncomeDataAdapter;
    }
};
