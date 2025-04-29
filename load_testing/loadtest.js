import http from 'k6/http';
import { sleep, check, group } from 'k6';

export let options = {
    // TODO: pass in users and duration from command line
    vus: 100, // number of virtual users
    duration: '30s',
};

const TOKENS = __ENV.USER_TOKENS;
const URL = __ENV.URL;

if(TOKENS === undefined) {
    throw new Error("cant run script. please defined ENV USER_TOKENS");
}

if(URL === undefined) {
    throw new Error("cant run script. please defined ENV URL");
}

export default function () {
    let headers;
    let tokenList = TOKENS.split(",");
    group("logging in", () => {
        // TODO: pass in base url + path from command line
        // let res = http.get(`${URL}/sandbox`);
        // check(res, { 'status is 200': (r) => (r.status === 200) });


        let randomToken = tokenList[Math.floor(Math.random() * tokenList.length)]

        headers = {
            'Cookie': `_iv_cbv_payroll_session=${randomToken}`,
        };
    })


    group("Submission page", () => {
        const res3 = http.get(URL, { headers });

        check(res3, {
            'authorized page loaded': (r) => r.status === 200,
        });

        sleep(0.5)
    })

}
