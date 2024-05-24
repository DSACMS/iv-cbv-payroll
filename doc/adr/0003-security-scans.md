# 3. Security Scans

Date: 2024-04-23

## Status

Accepted

## Context

In order to maintain a secure system, it is important that we are kept notified of any potential
vulnerabilities as early as possible, so we can mitigate them.

## Decision

We will add four new scans to our CI/CD Pipeline.

### Brakeman

Brakeman is a static code scanner designed to find security issues in Ruby on Rails code. It can flag
potential SQL injection, Command Injection, open redirects, and other common vulnerabilities.

### Bundle Audit

bundle-audit checks our Ruby dependencies against a database of known CVE numbers.

### Npm Audit

npm audit checks our Javascript dependencies against a database of known CVE numbers.

### OWASP ZAP

[OWASP ZAP](https://www.zaproxy.org/) is a dynamic security scanner that can simulate actual attacks on a running server.

An additional `RAILS_ENV` has been created called `ci`. It inherits from `production` to ensure
that the system being tested is as close as possible to `production` while allowing for overrides such
as bypassing authentication in a secure way.

## Consequences

We now have real-time information on any security vulnerabilities we may have introduced, as well as continuous
monitoring and alerting of discovered vulnerabilities in our software dependencies.

Our system security posture is overall improved by these additions.
