import http from 'k6/http';
import { sleep, check, group } from 'k6';

export let options = {
    vus: 5000, // number of virtual users
    duration: '60s',
};

const TOKENS = __ENV.USER_TOKENS;

export default function () {
    let headers;
    let tokenList = TOKENS.split(",");
    group("logging in", () => {
        let res = http.get("http://localhost:3000/sandbox/sso");
        check(res, { 'status is 200': (r) => r.status === 200 });

        let randomToken = tokenList[Math.floor(Math.random() * tokenList.length)]
        let loginRes = http.get("http://localhost:3000/en/cbv/entry?token=" + randomToken)
        check(loginRes, { 'load test status is 200': (r) => r.status === 200 });

        const cookies = loginRes.cookies['_iv_cbv_payroll_session'];
        const sessionCookie = cookies && cookies.length > 0 ? cookies[0].value : null;

        if (!sessionCookie) {
            console.error('No session cookie found');
            return;
        }

        headers = {
            'Cookie': `_ib_cbv_payroll_session=${sessionCookie}`,
        };
    })


    group("Submission page", () => {
        const res3 = http.get('http://localhost:3000/cbv/submit.pdf', { headers });


        check(res3, {
            'authorized page loaded': (r) => r.status === 200,
        });

        sleep(0.5)
    })

}