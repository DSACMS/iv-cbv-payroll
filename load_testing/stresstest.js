import http from 'k6/http';
import { sleep, check, group } from 'k6';
import { Counter } from 'k6/metrics';

// --- Configuration for each run ---
const RAMP_UP_DURATION = '5m';
const RAMP_DOWN_DURATION = '1m';
const TARGET_VUS = 10000;

const SLA_IN_MILLISECONDS = 2000;
const COOKIE = __ENV.COOKIE;
const URL = __ENV.URL;

const httpFailureCounter = new Counter('http_failures');
const failedSloCounter = new Counter("failed_slo");

export let options = {
    stages: [
        { duration: RAMP_UP_DURATION, target: TARGET_VUS },
        { duration: RAMP_DOWN_DURATION, target: 0 },
    ],
    thresholds: {
        'http_failures': [{ threshold: 'count<10', abortOnFail: true }],
        'failed_slo': [{ threshold: 'count<=0', abortOnFail: true }],
        'http_req_duration': ['p(95)<500', 'p(99)<1000', 'max<2000'],
        'checks': ['rate>0.9'],
    },
    maxRedirects: 0,
    summaryTrendStats: ['avg', 'med', 'p(95)', 'p(99)', 'max'],
};

if (COOKIE === undefined) {
    throw new Error("Can't run script. Please define ENV COOKIE.");
}
if (URL === undefined) {
    throw new Error("Can't run script. Please define ENV URL.");
}

export default function () {
    let headers;
    group("Submission page", () => {
        headers = { 'Cookie': `_iv_cbv_payroll_session=${COOKIE}` };
        const response = http.get(URL, { headers });

        const isSuccess = check(response, { 'authorized page loaded': (r) => r.status === 200 });

        if (!isSuccess) {
            httpFailureCounter.add(1);
        }

        if (response.timings.duration > SLA_IN_MILLISECONDS) {
            failedSloCounter.add(1)
        }
    });

    // This determines how each VU behaves; they access the page 4x a minute.
    group("Delay", () => { sleep(15) });
}
