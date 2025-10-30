# Governance
This project seeks to provide agencies responsibility for benefit eligibility determinations with an affordable platform to obtain the data they need. We want this platform:

- To show an applicant what data is being sent and get their explicit agreement
- Avoid storing any unnecessary information about particular applicants
- Integrate with existing workflows and infrastructures

## Glossary

- Do me last\! Anything that’s a ‘proper noun’, similar to example here: [https://dsacms.github.io/ospo-guide/resources/glossary/\#custom-developed-code](https://dsacms.github.io/ospo-guide/resources/glossary/#custom-developed-code)

## Project Scope

- The open source offering consists of all necessary assets to build a docker image along with the necessary documentation
-
- Community scope will shift over time, and to begin, we will engage with the IVaaS community to define the initial scope, and an expanded short and medium term scope that we are working towards.

## Community Principles

- Community principles and processes can be found in our [COMMUNITY.md](http://COMMUNITY.md) file in the project repository.

## Development Principles

[CONTRIBUTING.md](./CONTRIBUTING.md)

## Contributor Ladder / Role Definitions

See CONTRIBUTER\_LADDER.md

## Standards and Release

### Version Convention

- We will follow semantic version: [https://semver.org/](https://semver.org/)
  - If a change breaks backwards compatibility, then it will increment the major version
  - If a change introduces a new feature, or deprecates an old feature than it will update the minor version
  - If a feature is tweaked or a very small one is added, or a bug fix is pushed, that will increment the page version

### Release Lifecycle

Nava describes the existing process here.

(We describe an ideal future state we would like to get to in the future, and point to a specific section [CONTRIBUTING.md](http://CONTRIBUTING.md) or other doc here, e.g. [Release Format and Platform](https://github.com/DSACMS/iv-cbv-payroll/blob/main/CONTRIBUTING.md#writing-pull-requests))

### Release Format & Platform

- Generally, IVaaS strives to adhere to the CMS Open Source Release Guidance outlined here: [https://dsacms.github.io/ospo-guide/outbound/release-guidelines/](https://dsacms.github.io/ospo-guide/outbound/release-guidelines/)
- A git tag will be made for each release, the tag will be the version string prefixed with a ‘v’ (i.e. ‘vX.Y.Z’)
- Each git tag will also correspond to a github “release”: [https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
- Pre-built docker images will be pushed to DockerHub for each release, tagged with the version string. Additionally, the ‘latest’ tag will be updated with each release and each major / minor versions will have tags corresponding to the most recent sub-version
- Releases will update the [CHANGELOG.md](http://CHANGELOG.md) file to appropriately describe important updates

### Accessibility Standards

Accessibility standards will follow the guidelines from USWDS: [https://designsystem.digital.gov/](https://designsystem.digital.gov/) and adhere to specifications from GSA: [https://www.gsa.gov/website-information/accessibility-statement](https://www.gsa.gov/website-information/accessibility-statement), currently that means working with [WCAG 2.1](https://www.w3.org/WAI/standards-guidelines/wcag/), but we will update versions as GSA does.

Section 508 Compliance
21st Century IDEA Act Compliance

### Localization & Internalization Standards

We ensure that this platform supports switching between different locales, but only provide support for English and Spanish within this repository. We want to ensure that new languages can be added by anyone who wishes to extend the system by documenting the process.

## Decision making

### Changes to project scope

As with other Tier4 Open Source Community Projects at HHS/CMS, IVaaS is taking a 'co-planning' approach to do community-informed roadmapping.

The CONTRIBUTOR-LADDER.md file outlines how committer and maintainer privileges are distributed and managed.

DESIGN-PROPOSAL.md and ARCHITECTURE-PROPOSAL.md outline the process by which product and infrastructure suggestions are prioritized and decided.

TECHRADAR.md outlines the overall technology stack and tooling constraints that the project operates within, and the process by which new major technologies are introduced to the project.

CONTRIBUTING.md defines the context, conditions, and processes by which contributions to the project are made.

ISSUE\_TEMPLATE\*.md and PULL\_REQUEST\_TEMPLATE.md define the mechanics of how changes are proposed and merged.

### Bug Reports

Bug reports should be made through github issues using the Bug Report template.

### Feature Requests

Feature requests should be made through GitHub issues using the [Feature Request template](#).

## Tech Radar

## Community Communication

### Accepting General Feedback

We will create an email address to accept feedback from users. Additionally, feedback can be given through [GitHub discussions](#), and Issues. (Forking This [https://hhs.github.io/lodp-UX/](https://hhs.github.io/lodp-UX/))

### Communicating roadmap

Active work can be tracked by the public through repository [issues](https://github.com/DSACMS/iv-cbv-payroll/issues) and GitHub project boards. The project page will communicate planned milestones and labels on GitHub issues.

### User-specific tech support

(define SLA for GitHub issues here) No user tech support
