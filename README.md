# Eligibility Made Easy (Emmy)

## About the Project
Emmy is a suite of federally developed digital tools designed to help states meet Medicaid eligibility requirements and help beneficiaries navigate those requirements more easily.

Emmy was created to address a growing gap: states are being asked to verify eligibility across an expanding set of requirements, but many lack the infrastructure to do so affordably, accurately, and at scale. Emmy is CMS’s response — a low-cost, federally maintained verification layer that states can adopt without needing to replace or rebuild their existing eligibility systems.

Emmy includes two components that can be used together or independently, depending on state needs:

**Emmy App** — a direct-to-beneficiary web application that provides Medicaid clients with a simple, human-centered way to complete eligibility-related tasks. Designed with an applicant-first approach, the Emmy App guides users through reporting and verifying information — starting with Community Engagement (CE) activities and income — connects to trusted data sources to reduce redundant questions, and generates a standardized, audit-ready evidence package for the state.

**Emmy API** — a backend data service that gives states automated, cost-effective access to the verification data needed to support eligibility determinations, without replacing existing systems. The Emmy API connects states to federal and commercial data sources, beginning with VA Lighthouse (veteran disability verification, available at no cost to states) and the National Student Clearinghouse (education enrollment verification).

Emmy is built and maintained by the Centers for Medicare & Medicaid Services (CMS) and is under active development, with new releases on a two-week cadence.

## Contributing

For a guide to running the Emmy project on your own, and submitting changes, see [CONTRIBUTING.md](/CONTRIBUTING.md).

## Core Team

The Emmy core team is a group of technologists, composed of engineers, designers, product, and procurement specialists at Centers of Medicare and Medicaid Services (CMS). The products developed are open source and SHARE IT compliant.

A list of core team members responsible for the code and documentation in this repository can be found in [COMMUNITY.md](/COMMUNITY.md) and [CODEOWNERS.md](/CODEOWNERS.md).

## Documentation

### Repository Structure

* [/.github](/.github) GitHub specific settings files and testing, linting, and CI/CD workflows  
* [/app](/app) the Emmy web application built using Rails  
* [/bin](/bin) scripts for managing infrastructure  
* [/docs](/docs) public documentation for developers  
* [/infra](/infra) contains infrastructure-as-code and documentation of replication steps for Emmy environment  
* [/load\_testing](/load_testing) load testing resources

See [AGENTS.md](/app/AGENTS.md) for some more information on repo structure.

### Documentation

Public documentation is in the [/docs](/docs) subfolder.

### Architectural Decision Records (ADRs)

Our ADRs are stored in [CMS Confluence](https://confluenceent.cms.gov/pages/viewpage.action?pageId=693666588) and not currently accessible to the public.

### Community

The CMS Emmy team is taking an open source approach to the product development of this tool. We believe government software should be made in the open and be built and licensed such that anyone can download the code, run it themselves, modify the project to fit their state’s needs, and then share their updates with the open source community.

We know that we can learn from a wide variety of communities, including those who will use or will be impacted by the tool, who are experts in technology, or who have experience with similar technologies deployed in other spaces. We are dedicated to creating forums for continuous conversation and feedback to help shape the design and development of the tool.

We also recognize capacity building as a key part of involving a diverse open source community. We are doing our best to use accessible language, provide technical and process documents, and offer support to community members with a wide variety of backgrounds and skillsets.

For more information on how the Emmy team works with our community, see [COMMUNITY.md](/COMMUNITY.md) and [GOVERNANCE.md](/GOVERNANCE.md).

## Feedback

If you have ideas for how we can improve or add to our capacity building efforts and methods for welcoming people into our community, please let us know by sending an email to: ffs at nava pbc dot com. If you would like to comment on the tool itself, please let us know by [filing an issue on our GitHub repository](https://github.com/DSACMS/iv-cbv-payroll/issues/new/choose).

## Policies

### Open Source Policy

We adhere to the [CMS Open Source Policy](https://github.com/CMSGov/cms-open-source-policy). If you have any questions, just shoot us an email.

### Security and Responsible Disclosure Policy

*Submit a vulnerability:* Unfortunately, we cannot accept secure submissions via email or via GitHub Issues. Please use our website to submit vulnerabilities at [https://hhs.responsibledisclosure.com](https://hhs.responsibledisclosure.com/). HHS maintains an acknowledgements page to recognize your efforts on behalf of the American public, but you are also welcome to submit anonymously.

For more information about our Security, Vulnerability, and Responsible Disclosure Policies, see [SECURITY.md](/SECURITY.md).

### Software Bill of Materials (SBOM)

A Software Bill of Materials (SBOM) is a formal record containing the details and supply chain relationships of various components used in building software.

In the spirit of [Executive Order 14028 \- Improving the Nation’s Cyber Security](https://www.gsa.gov/technology/it-contract-vehicles-and-purchasing-programs/information-technology-category/it-security/executive-order-14028), a SBOM for this repository is provided here: [https://github.com/DSACMS/iv-cbv-payroll/network/dependencies](https://github.com/DSACMS/iv-cbv-payroll/network/dependencies).

For more information and resources about SBOMs, visit: [https://www.cisa.gov/sbom](https://www.cisa.gov/sbom).

### Public domain

This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/) as indicated in [LICENSE](/LICENSE).

All contributions to this project will be released under the CC0 dedication. By submitting a pull request or issue, you are agreeing to comply with this waiver of copyright interest.  
