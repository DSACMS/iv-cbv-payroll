# Load Testing

## Overview

### Test Files

- **`loadTestUserFlow.js`** - Session-based user flow tests (sync polling, payment details, summary, PDF, employer search)
- **`loadTestAPI.js`** - API key authenticated bulk invitation creation tests
- **`loadTestAll.js`** - Orchestrator running both test suites in parallel
- **`common.js`** - Shared utilities (constants, metrics, helper functions)

### Architecture

Each test file can run independently or be orchestrated together via `loadTestAll.js`. Sessions are automatically managed and reused within VUs for realistic user behavior.

## Running a Load Test

Load tests must be performed from our loadtesting EC2 instance in order for accurate readings to be useful.

Follow these steps to perform a load test:

### Preparation
1. Ensure you're running k6 within EC2
2. Ensure you've pre-scaled up the ECS service and database cluster to expected load levels. Standard levels are:
    * ECS service (app-dev) = 5-10 containers (tasks)
    * DB cluster (app-dev) = 5-10 ACUs
3. Pause the "default" queue so we don't track a ton of useless Mixpanel events during the test.
    * https://demo.divt.app/jobs      (un/pw in 1Password)

### Running the tests

#### Option 1: User Flow Tests (`loadTestUserFlow.js`)

Tests session-based user flows through the CBV application.

**Load pattern:**
- 10 concurrent VUs (virtual users)
- Ramp up: 60s, sustain: 30s, ramp down: 30s
- Mixed scenario distribution: 50% sync polling, 20% employer search, 15% payment details, 10% summary, 5% PDF

**Session generation:** Uses dynamic session generation via dev-only API endpoint (`/api/load_test/sessions`)

```bash
# Run user flow tests with default mixed scenarios
k6 run loadTestUserFlow.js \
  --env URL=https://demo.divt.app \
  --env CLIENT_AGENCY_ID=sandbox

# Run specific scenario only
k6 run loadTestUserFlow.js \
  --env URL=https://demo.divt.app \
  --env CLIENT_AGENCY_ID=sandbox \
  --env SCENARIO=sync
```

**Available scenarios:**
- `mixed` (default) - Weighted distribution across all scenarios
- `sync` - Database-intensive synchronization polling (tests pending data)
- `payment_details` - Per-account queries and aggregation
- `summary` - Full summary with all accounts
- `pdf` - CPU-intensive PDF generation
- `employer_search` - Employer search page

**Note:** Sessions are automatically created with the appropriate data state:
- `sync` scenario → creates sessions with `pending` data (to test polling behavior)
- All other scenarios → creates sessions with `synced` data (to display results)

#### Option 2: API Tests (`loadTestAPI.js`)

Tests bulk invitation creation via API endpoint.

**Load pattern:**
- Constant arrival rate: 100 invitations/second
- Duration: 2 minutes
- Total invitations created: ~12,000
- VUs: 10 pre-allocated, scales up to 50 if needed

**Authentication:** Requires API key (Bearer token)

```bash
# Run API bulk creation test
k6 run loadTestAPI.js \
  --env URL=https://demo.divt.app \
  --env API_KEY=your_api_token_here
```

**What it tests:**
- POST `/api/v1/invitations` endpoint performance
- Database write throughput
- Invitation token generation
- Response time under sustained load

#### Option 3: Combined Tests (`loadTestAll.js`)

Runs both user flow and API tests in parallel to simulate realistic mixed load.

```bash
# Run all tests simultaneously
k6 run loadTestAll.js \
  --env URL=https://demo.divt.app \
  --env CLIENT_AGENCY_ID=sandbox \
  --env API_KEY=your_api_token_here
```

**Combined load:**
- User flows: 10 VUs doing mixed scenarios
- API: 100 invitations/second bulk creation
- Both run concurrently for realistic production simulation

### Metrics

All tests output performance metrics including:
- Request duration (avg, median, p95, p99, max)
- Check success rate
- SLO violations (responses > 2000ms)
- HTTP request duration thresholds (p95<500ms, p99<1000ms, max<2000ms)

### Cleanup
1. Delete test sessions from database:
    ```bash
    # In the Rails console or via rake task
    bin/rails 'load_test:cleanup_sessions[sandbox]'
    ```

2. Delete all jobs enqueued within the "default" job queue:
    ```bash
    # in top-level of repo
    bin/ecs-console

    # in the Rails console that opens:
    > SolidQueue::Queue.new("default").clear
    ```

3. Resume the "default" queue execution.
    * https://demo.divt.app/jobs      (un/pw in 1Password)


## Developing Locally with K6

The instructions below are for local development/prototyping of the load testing script (not intended to produce calibrated metrics).

### Installing k6 locally

```bash
brew install k6
```

### Running tests locally

**User flow tests:**
```bash
# Ensure your local server is running
bin/rails server

# Run user flow tests
k6 run loadTestUserFlow.js \
  --env URL=http://localhost:3000 \
  --env CLIENT_AGENCY_ID=sandbox

# Run specific scenario
k6 run loadTestUserFlow.js \
  --env URL=http://localhost:3000 \
  --env CLIENT_AGENCY_ID=sandbox \
  --env SCENARIO=sync
```

**API tests:**
```bash
# First, create an API access token in your local environment
bin/rails console
# > user = User.find_by(email: 'your@email.com')
# > token = user.api_access_tokens.create!
# > puts token.access_token

# Run API tests with your token
k6 run loadTestAPI.js \
  --env URL=http://localhost:3000 \
  --env API_KEY=your_token_here
```

**Combined tests:**
```bash
k6 run loadTestAll.js \
  --env URL=http://localhost:3000 \
  --env CLIENT_AGENCY_ID=sandbox \
  --env API_KEY=your_token_here
```

### Monitoring with Grafana (Optional)

For local metrics visualization:

```bash
docker-compose up
```

**Grafana setup:**
1. Visit http://localhost:3001
2. Login: admin / admin
3. Add InfluxDB data source:
   - URL: http://influxdb:8086
   - Database: k6
   - HTTP method: GET
4. Import dashboard: https://grafana.com/grafana/dashboards/13719-k6-load-testing-results-by-groups/

**Run tests with InfluxDB output:**
```bash
K6_OUT=influxdb k6 run loadTestUserFlow.js \
  --env URL=http://localhost:3000 \
  --env CLIENT_AGENCY_ID=sandbox
```


## Running on EC2 Instance

For production-grade load testing, use the dedicated loadtester EC2 instance.

### Setup

**Checkout repo into EC2 container:**
```bash
git checkout https://github.com/Digital-Public-Works/iv-cbv-payroll.git
cd load_testing
```

**Install k6 (one-time setup):**
```bash
sudo dnf install https://dl.k6.io/rpm/repo.rpm
sudo dnf install k6
```

### Running tests on EC2

```bash
# User flow tests
k6 run loadTestUserFlow.js \
  --env URL=https://demo.divt.app \
  --env CLIENT_AGENCY_ID=sandbox

# API tests
k6 run loadTestAPI.js \
  --env URL=https://demo.divt.app \
  --env API_KEY=your_token_here

# Combined tests
k6 run loadTestAll.js \
  --env URL=https://demo.divt.app \
  --env CLIENT_AGENCY_ID=sandbox \
  --env API_KEY=your_token_here
```
