import http from 'k6/http';
import { sleep, check, group } from 'k6';
import { Counter } from 'k6/metrics';

export let options = {
    vus: 0, // start at 0 users, and ramp up linearly
    stages: [
        { duration: '60s', target: 2500 },
        { duration: '30s', target: 2500 },
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
const COOKIE = __ENV.COOKIE;
const URL = __ENV.URL;
const failedSloCounter = new Counter("failed_slo")

if(COOKIE === undefined) {
    throw new Error("cant run script. please defined ENV COOKIE");
}

if(URL === undefined) {
    throw new Error("cant run script. please defined ENV URL");
}

export default function () {
    let headers;

    group("Submission page", () => {
        headers = {
            'Cookie': `_iv_cbv_payroll_session=${COOKIE}`,
        };
        const response = http.get(URL, { headers });

        check(response, {
            'authorized page loaded': (r) => r.status === 200,
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
