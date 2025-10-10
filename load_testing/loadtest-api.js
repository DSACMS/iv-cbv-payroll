import http from 'k6/http';
import { sleep, check, group } from 'k6';
import { Counter } from 'k6/metrics';

export let options = {
    vus: 0, // start at 0 users, and ramp up linearly
    stages: [
        { duration: '60s', target: 3500 },
        { duration: '30s', target: 3500 },
        { duration: '30s', target: 0 },
    ],
    maxRedirects: 0,
    thresholds: {
        // bail early if more than 10% of checks are failing (bad cookie?)
        checks: [{ threshold: 'rate>0.1', abortOnFail: true }],
        // measure against our SLO for p95, p99, and max durations
        failed_slo: ['count<=0'],
        http_req_duration: ['p(95)<500', 'p(99)<1000', 'max<2000'],
    },
    summaryTrendStats: ['avg', 'med', 'p(95)', 'p(99)', 'max'],
};

const SLA_IN_MILLISECONDS = 2000;
const API_KEY = __ENV.API_KEY;
const HOST = __ENV.HOST;
const failedSloCounter = new Counter("failed_slo")

if(API_KEY === undefined) {
    throw new Error("cant run script. please define API_KEY environment variable");
}

if(HOST === undefined) {
    throw new Error("cant run script. please defined HOST environment variable");
}

export default function () {
    const headers = {
        'Authorization': `Bearer ${API_KEY}`,
        'Content-Type': "application/json"
    };
    const payload = {
        language: "en",
        client_agency_id: "az_des",
        agency_partner_metadata: {
            case_number: "443322",
            income_changes: []
        }
    };

    group("Tokenized Link API", () => {
        const url = HOST + "/api/v1/invitations";
        const response = http.post(url, JSON.stringify(payload), { headers });

        check(response, {
            'invitation created': (r) => r.status === 201,
        });

        if (response.timings.duration > SLA_IN_MILLISECONDS) {
            failedSloCounter.add(1)
        }
    });

    // Time between requests for a given user.
    // 15 seconds is the default to accommodate a 2 minute CBV session that
    // hits 8 pages (= 15 seconds/page).
    group("Delay", () => { sleep(15) });
}

// vim: expandtab sw=4 ts=4
