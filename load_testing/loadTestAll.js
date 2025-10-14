import runUserFlow  from './loadTestUserFlow.js';
import runAPITest from './loadTestAPI.js';

export let options = {
    scenarios: {
        // User flow tests - session-based
        user_flows: {
            executor: 'ramping-vus',
            startVUs: 0,
            stages: [
                { duration: '60s', target: 10 },
                { duration: '30s', target: 10 },
                { duration: '30s', target: 0 },
            ],
            exec: 'userFlow',
        },
        // API tests - token-based bulk creation
        api_invitations: {
            executor: 'constant-arrival-rate',
            rate: 100,              // 100 invitations per second
            timeUnit: '1s',
            duration: '2m',
            preAllocatedVUs: 10,
            maxVUs: 50,
            exec: 'apiInvitations',
        },
    },
    thresholds: {
        checks: [{ threshold: 'rate>0.90', abortOnFail: true }],
        failed_slo: ['count<=0'],
        http_req_duration: ['p(95)<500', 'p(99)<1000', 'max<2000'],
    },
    summaryTrendStats: ['avg', 'med', 'p(95)', 'p(99)', 'max'],
};

// User flow test function - delegates to loadTestUserFlow
export function userFlow() {
    runUserFlow();
}

// API test function - delegates to loadTestAPI
export function apiInvitations() {
    runAPITest();
}

// vim: expandtab sw=4 ts=4
