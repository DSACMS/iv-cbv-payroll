import http from 'k6/http';
import { check, group } from 'k6';
import { URL, checkSlo } from './common.js';

export let options = {
    scenarios: {
        bulk_create: {
            executor: 'constant-arrival-rate',
            rate: 100,              // 100 invitations per second
            timeUnit: '1s',
            duration: '2m',
            preAllocatedVUs: 50,
            maxVUs: 100,            // Allow scaling if needed
        },
    },
    thresholds: {
        checks: [{ threshold: 'rate>0.95', abortOnFail: true }],
        failed_slo: ['count<=0'],
        http_req_duration: ['p(95)<500', 'p(99)<1000', 'max<2000'],
    },
    summaryTrendStats: ['avg', 'med', 'p(95)', 'p(99)', 'max'],
};

const API_KEY = __ENV.API_KEY;

if(!API_KEY) {
    throw new Error("API_KEY environment variable is required");
}

export default function () {
    testCreateInvitation();
}

function testCreateInvitation() {
    group("Create invitation (API)", () => {
        const payload = JSON.stringify({
            language: 'en',
            agency_partner_metadata: {
                case_number: `LOAD_TEST_${Date.now()}_${Math.random().toString(36).substring(7)}`
            }
        });

        const response = http.post(
            `${URL}/api/v1/invitations`,
            payload,
            {
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${API_KEY}`,
                }
            }
        );

        check(response, {
            'invitation created': (r) => r.status === 201,
            'has tokenized_url': (r) => {
                const body = JSON.parse(r.body);
                return body.tokenized_url !== undefined;
            },
        });

        checkSlo(response);
    });

    // No sleep needed - constant-arrival-rate executor controls the rate
}

// vim: expandtab sw=4 ts=4
