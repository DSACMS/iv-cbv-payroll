installing k6 locally:

```
brew install k6
```

instructions for running load tests locally:

In Grafana, add a data source: choose InfluxDB

URL: influxdb:8086

Database: k6

HTTP method: GET

In grafana, add a dashboard:

use this dashboard as inspiration:
https://grafana.com/grafana/dashboards/13719-k6-load-testing-results-by-groups/

Figure out what CBV flow invitation tokens you want to use locally

Then pass those into the script

K6_OUT=influxdb k6 run loadtest.js --env USER_TOKENS=<COMMA_SEPERATED_TOKENS> --env URL_BASE=http://localhost:3000

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

# grabbing appropriate user tokens

You'll need a cbv flow invitation URL that isn't expired. Then log in manually yourself, set up whatever you want to
do (in this case, making sure there's an appropriate pdf generated). Then go to inspect element in chrome -->
application --> cookies. Get the NON url decoded value, supply that into USER_TOKENS above.
