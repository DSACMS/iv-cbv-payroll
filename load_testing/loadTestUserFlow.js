import http from 'k6/http';
import { sleep, check, group } from 'k6';
import {
    URL,
    CLIENT_AGENCY_ID,
    checkSlo,
    SIMULATE_DELAY_SYNC_POLLING_S,
    SIMULATE_DELAY_PAYMENT_DETAILS_S,
    SIMULATE_DELAY_SUMMARY_S,
    SIMULATE_DELAY_PDF_DOWNLOAD_S,
    SIMULATE_DELAY_EMPLOYER_SEARCH_S,
    SYNC_POLL_COUNT,
    USER_FLOW_STEPS
} from './common.js';

export let options = {
    vus: 0, // start at 0 users, and ramp up linearly
    stages: [
        { duration: '60s', target: 10 },
        { duration: '30s', target: 10 },
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

const SCENARIO = __ENV.SCENARIO || 'mixed'; // 'mixed', 'sync', 'summary', 'pdf'

// Session manager - reuses sessions across iterations per VU
const getOrCreateSession = (() => {
    let pendingSession;  // For sync tests
    let syncedSession;   // For everything else

    return (scenario) => {
        if (scenario === 'sync') {
            if (!pendingSession) {
                pendingSession = createSession('pending');
            }
            return pendingSession;
        } else {
            if (!syncedSession) {
                syncedSession = createSession('synced');
            }
            return syncedSession;
        }
    };
})();

export default function () {
    const scenario = SCENARIO === 'mixed' ? selectScenario() : SCENARIO;
    const session = getOrCreateSession(scenario);

    if (session) {
        executeTestScenario(scenario, session);
    }
}

function createSession(dataState) {
    const headers = {
        'Accept': 'text/html,application/xhtml+xml,application/xml',
    };

    // Request a fresh session from the dev endpoint
    const sessionResponse = http.post(`${URL}/api/load_test/sessions`, JSON.stringify({
        client_agency_id: CLIENT_AGENCY_ID,
        scenario: dataState
    }), {
        headers: {
            'Content-Type': 'application/json'
        }
    });

    if (sessionResponse.status === 201) {
        // Extract session cookie from Set-Cookie header (Rails automatically encrypts it)
        const sessionCookie = sessionResponse.cookies['_iv_cbv_payroll_session'];
        if (sessionCookie && sessionCookie[0]) {
            headers['Cookie'] = `_iv_cbv_payroll_session=${sessionCookie[0].value}`;

            // Extract account_id and csrf_token from response body
            const sessionData = JSON.parse(sessionResponse.body);

            return {
                headers: headers,
                accountId: sessionData.account_id,
                csrfToken: sessionData.csrf_token
            };
        } else {
            console.error('No session cookie in response');
            return null;
        }
    } else {
        console.error('Failed to create session:', sessionResponse.status, sessionResponse.body);
        return null;
    }
}

function executeTestScenario(scenario, session) {
    switch(scenario) {
        case 'sync':
            testSynchronization(session);
            break;
        case 'payment_details':
            testPaymentDetails(session);
            break;
        case 'summary':
            testSummary(session);
            break;
        case 'pdf':
            testPdfGeneration(session);
            break;
        case 'employer_search':
            testEmployerSearch(session);
            break;
    }
}

function selectScenario() {
    const rand = Math.random();

    // Distribution based on typical user time per page:
    // - 77% Synchronization (longest wait, most DB polling)
    // - 10% Employer search
    // - 5% Payment details review
    // - 3% Summary page
    // - 5% PDF generation

    if (rand < 0.77) return 'sync';
    if (rand < 0.87) return 'employer_search';
    if (rand < 0.92) return 'payment_details';
    if (rand < 0.95) return 'summary';
    return 'pdf';
}

function testSynchronization(session) {
    const { headers, accountId, csrfToken } = session;

    group("Synchronization polling (DB intensive)", () => {
        const requestHeaders = {
            ...headers,
            'Content-Type': 'application/json',
            'Accept': 'text/vnd.turbo-stream.html',
        };

        // Add CSRF token if available (for dynamic sessions)
        if (csrfToken) {
            requestHeaders['X-CSRF-Token'] = csrfToken;
        }

        const response = http.patch(
            `${URL}/cbv/synchronizations?user%5Baccount_id%5D=${accountId}`, {},
            { headers: requestHeaders }
        );

        check(response, {
            'synchronization check succeeded': (r) => r.status === 200,
        });

        checkSlo(response);
    });

    // Realistic polling interval
    sleep(SIMULATE_DELAY_SYNC_POLLING_S);
}

function testPaymentDetails(session) {
    const { headers, accountId } = session;

    group("Payment details (DB + aggregation)", () => {
        const response = http.get(
            `${URL}/cbv/payment_details?user%5Baccount_id%5D=${accountId}`,
            { headers }
        );

        check(response, {
            'payment details loaded': (r) => r.status === 200,
        });

        checkSlo(response);
    });

    // Time reviewing payment details
    sleep(SIMULATE_DELAY_PAYMENT_DETAILS_S);
}

function testSummary(session) {
    const { headers } = session;

    group("Summary page (aggregation)", () => {
        const response = http.get(
            `${URL}/cbv/summary`,
            { headers }
        );

        check(response, {
            'summary loaded': (r) => r.status === 200,
        });

        checkSlo(response);
    });

    // Time reviewing summary
    sleep(SIMULATE_DELAY_SUMMARY_S);
}

function testPdfGeneration(session) {
    const { headers } = session;

    group("PDF generation (CPU intensive)", () => {
        const response = http.get(
            `${URL}/cbv/submit.pdf`,
            {
                headers: {
                    ...headers,
                    'Accept': 'application/pdf',
                }
            }
        );

        check(response, {
            'pdf generated': (r) => r.status === 200,
            'pdf content type': (r) => r.headers['Content-Type'] && r.headers['Content-Type'].includes('pdf'),
        });

        checkSlo(response);
    });

    // PDFs are downloaded less frequently
    sleep(SIMULATE_DELAY_PDF_DOWNLOAD_S);
}

function testEmployerSearch(session) {
    const { headers } = session;

    group("Employer search page", () => {
        const response = http.get(
            `${URL}/cbv/employer_search`,
            { headers }
        );

        check(response, {
            'is Status 200': (r) => r.status === 200,
        });

        checkSlo(response);
    });

    // Time searching for employer
    sleep(SIMULATE_DELAY_EMPLOYER_SEARCH_S);
}

// vim: expandtab sw=4 ts=4
