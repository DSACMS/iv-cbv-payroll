installing k6 locally:

```
brew install k6
```

instructions for running load tests locally:

In Grafana, add a data source: choose InfluxDB

URL: http://influxdb:8086

Database: k6

HTTP method: GET

In grafana, add a dashboard:

use this dashboard as inspiration:
https://grafana.com/grafana/dashboards/13719-k6-load-testing-results-by-groups/



Figure out what CBV flow invitation tokens you want to use locally

Then pass those into the script

K6_OUT=influxdb k6 run loadtest.js --env USER_TOKENS=<COMMA_SEPERATED_TOKENS> --env URL_BASE=http://localhost:3000
