### Installing k6 locally & starting container:

```
brew install k6

docker-compose up
```

### Instructions for running load tests locally:

Grafana URL: http://localhost:3001
Default username: admin
Default password: admin

In Grafana, add a data source: choose InfluxDB

URL: http://influxdb:8086

Database: k6

HTTP method: GET

Click save & test

In Grafana, add a dashboard:

use this dashboard as inspiration:
https://grafana.com/grafana/dashboards/13719-k6-load-testing-results-by-groups/

If you'd like to import this dashboard, select "import dashboard" and copy-paste the above URL.

### Grabbing appropriate user tokens

Set up a user in the environment you'd like to load test. While logged in as the user, in the browser console, grab the cookie `_iv_cbv_payroll_session`. Put the **NON** url decoded value, supply that into USER_TOKENS below.

K6_OUT=influxdb k6 run loadtest.js --env USER_TOKENS=<COMMA_SEPERATED_TOKENS> --env URL=<example: https://verify-demo.navapbc.cloud/cbv/employer_search>

####

instructions for running load tests on an ec2 instance
Note that there might be an EC2 instance called loadtester that has the tools necessary installed onto it.

copy the files into the ec2 instance using something like
scp -i ~/.ssh/my-ec2-key.pem load_testing/* ec2-user@<internal-ec2-link>:/home/ec2-user/

# for viewing the metrics

```
sudo yum install docker
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose up
```

# for running the load tests

sudo dnf install https://dl.k6.io/rpm/repo.rpm
sudo dnf install k6

# running without dumping into influxdb

k6 run loadtest.js --env USER_TOKENS=<COMMA_SEPERATED_TOKENS> --env URL_BASE=https://verify-demo.navapbc.cloud
