import { Counter } from 'k6/metrics';

// Shared constants
export const SLA_IN_MILLISECONDS = 2000;
export const URL = __ENV.URL;
export const CLIENT_AGENCY_ID = __ENV.CLIENT_AGENCY_ID || 'sandbox';

// Shared metrics
export const failedSloCounter = new Counter("failed_slo");

// Validate required environment variables
if(URL === undefined) {
    throw new Error("URL environment variable is required");
}

// Helper function to check if response exceeds SLO
export function checkSlo(response) {
    if (response.timings.duration > SLA_IN_MILLISECONDS) {
        failedSloCounter.add(1);
    }
}

// vim: expandtab sw=4 ts=4
