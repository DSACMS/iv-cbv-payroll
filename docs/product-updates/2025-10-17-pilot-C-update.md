---
subtitle: Authored by Digital Public Works
title: "**Consent-Based Verification Pilot C for Medicaid Data and Insights**"
---

# **Consent-Based Verification Pilot C for Medicaid Data and Insights**
### Authored by Digital Public Works
## **Executive Summary**

Pilot C for Medicaid was a milestone pilot because it was the first
consent-based income verification project with a state Medicaid (i.e.
not SNAP) partner agency. It also introduced the highest number of
beneficiaries to The Centers for Medicare and Medicaid Services (CMS)'s
Income Verification-as-a-Service (IVaaS) platform to date.

Over the course of 6 weeks, IVaaS's consent-based verification tool
helped 894 Medicaid clients submit proof of their income during this
pilot - primarily from mobile devices. Searching and logging in
presented challenges for clients, especially individuals who were
unemployed, but 54.8% of the sessions that attempted log in were
ultimately successful. Among client sessions that successfully logged in
78% submitted an Income Report back to the agency.

A survey of 139 caseworkers showed that caseworkers found it easy and
fast to use IVaaS's income reports (Income Reports), and state staff who
indexed the reports to the correct case found it to be easier than
paystubs. 

The pilot also demonstrated weaknesses inherent to using a generic link
rather than a unique or tokenized link to IVaaS's consent-based
verification tool. A generic link required Medicaid clients to enter
their date of birth and the option to also enter their case number. This
data entry presented another drop-off point. It also meant the product
data could not disambiguate multiple sessions in a single household from
discrete sessions across multiple households. Generic links also imposed
a greater burden on caseworkers to index reports to the correct Medicaid
case. Future pilots should use tokenized links to improve completion,
provide better data, and minimize manual effort.

## **Background**

The pilot was structured to prioritize speed to launch, minimal
imposition of burden to state resources, and sufficiency of volume to
test the hypotheses listed below.\
\
IVaaS CBV will:

- provide recent income data.

- provide accurate income data.

- provide complete data for income verification.

- generate an Income Report will be easy for caseworkers to index to the
  right person and case.

- verify income without additional client contact or RFIs.

The pilot was not structured to provide robust metrics on case outcomes.
Initial attempts to conduct case outcome analyses highlighted the need
for better methods of identifying cases that used IVaaS CBV.

The state agency deferred receiving machine-readable data for future
iterations and elected to receive income data in a secure email inbox
that was manually accessed. Prior to making such investments, the state
partner wanted to validate basic hypotheses around technical and
procedural viability and compatibility.  

The Medicaid pilot partner agency decided to run this same pilot again
in August of 2025 with minimal changes.

Pilot C for Medicaid launched on May 18, 2025 and concluded on June 30,
2025.


| Program       | **Medicaid**                                         |
| ------------- | ---------------------------------------------------- |
| **Point in Time** | The state has a legislative requirement to **re-verify income on a quarterly basis**. State Quarterly Wage Data is queried to check if the beneficiary is over the qualifying Federal Poverty Line for Medicaid. If Quarterly Wage Data returns results for a beneficiary and income is over the qualifying Federal Poverty Line, the beneficiary must submit verifiable income documents to prove they are still eligible. <br> *Note: If a beneficiary does not show up in Quarterly Wage Data, no action is taken.* |
| **How IVaaS CBV was introduced to clients** | Beneficiaries who were found to be over income in Quarterly Wage Data were sent a paper notice and text message that included a generic website address to CBV. [^1] <br> - **Mailed notices**: A generic URL was included in the copy. <br> - **Email**: An email notification directed beneficiaries to the client portal where they could view an online version of the paper notice. Only 16% of beneficiaries were enrolled in email notifications. <br> - **SMS / text**: A generic URL was included in the message. 86% of beneficiaries were enrolled text notifications. |
| **Type of link(s)** | **Generic Link**[^1] <br> Because the link was generic, not tokenized, beneficiaries needed to enter their date of birth in CBV. They had the option of providing their case number, too. Name was pulled from payroll data and included in the Income Report but was not visible to the beneficiary. The last 4 digits of their Social Security Number was also included if it was available. |
| **How IVaaS CBV’s Income Report was sent back to agency** | Income Reports were sent via encrypted email to an existing inbox, State document indexers (state staff) pulled Income Reports from this inbox to associate it with the correct case. |


[^1]: A “generic link” means each beneficiary receives the same website address. This contrasts with individualized or tokenized addresses where each website is unique to the user.  Because these forms of website addresses require lengthy URLs, they are best provided through digital means like text or email or, if on paper notices, through QR codes.

**IVaaS CBV product learnings**\
*What could be improved within the product?*

- **Search experience.** Clients entered acronyms and other terms that
  did not yield actionable, relevant results. It is unlikely to improve
  the search functionality sufficiently to account for acronyms, so more
  specific prompts for how to search might be useful (e.g. instead of an
  acronym, type the full name of the employer).

  - **Experience for clients who are unemployed or recently lost
    employment.** The current user experience does not help this user
    group realize they can use the tool or offboard them to relevant
    next steps. Help content is narrowly focused on finding providers /
    employers and logging in. The search experience doesn't provide
    instructions specific to this situation.

- **Log in support and off-boarding when log in fails.** Trouble logging
  in was a commonly viewed help topic and a point where people dropped
  off from IVaaS CBV. As the team learns more about log ins, stronger
  support and help content should be provided. When logging in presents
  a roadblock, IVaaS CBV should better guide clients to their next
  steps.

- **Payment review experience.** If a client finds the income data IVaaS
  CBV pulls to be incorrect, the only option is to leave a comment.
  Having the client validate the information is accurate or annotate
  what's inaccurate may be valuable to clients and caseworkers.

- **In-app feedback survey**. The survey that allows clients to provide
  feedback on IVaaS CBV and sign up for research sessions was only
  completed 5 times in this pilot period. The opportunity to provide
  feedback needs to be more visible throughout IVaaS CBV.

- **Unique user data.** Product data for this pilot was only available
  by session, not unique user. This inflated drop-off points, making it
  difficult to understand where there are problems in the experience and
  how prevalent they are.

- **Knowing where clients accessed the IVaaS CBV link.** In this pilot
  it was not possible to know if the client accessed the link from the
  text message, mailed notice, or e-notice. This is important data to
  collect moving forward to learn how introduction points impact
  clients' use of IVaaS CBV.

## **Pilot design learnings**

### What would we recommend adjusting in future pilots?

- **More context about IVaaS CBV at introduction**. Clients had taken no
  previous action related to reporting their income, so this notice and
  text message were unexpected. The paper and e-notice give the option
  to use CBV, but little context about it. Increasing context might
  increase engagement.

- **Use tokenized links when possible.** Using the tokenized link
  removes the need for clients to enter indexing information. It would
  also remove the manual indexing work for state staff.

- **More robust impact data.** To learn about IVaaS CBV's impact on case
  outcomes, timeliness, and RFIs, more robust data tracking and sampling
  would be needed. There needs to be a comparison or baseline group to
  compare case outcomes when using IVaaS CBV versus using existing
  methods. This would require an automated method to identify cases that
  used CBV and submitted and Income Report and a post-pilot analysis.

### How did the pilot design impact engagement?

Two factors likely contributed to lower engagement and drop-off:

1.  **Opting for the generic link instead of the tokenized link.**\
    Beneficiaries had to enter their date of birth and optionally could
    enter their case number. This step resulted in drop-off.

2.  **Introducing CBV after a passive data check.**\
    Beneficiaries had not taken recent action to report their income.
    The quarterly wage check happens in the background and loops the
    beneficiary in only if they need to submit income verification. The
    call center saw several questions come in from beneficiaries who
    were wondering why they needed to verify their income again.


# **Pilot C for Medicaid Impact Summary**

## Section 1: **IVaaS CBV Income Reports** 

#### 1A) **Overview**

In Pilot C for Medicaid, 894 CBV Income Reports were submitted. This
section examines the data gathered in submitted reports.

### IVaaS CBV Income Reports

| Metric       | Pilot Result                                        |
| ------------- | ---------------------------------------------------- |
| Total number of cases that received a link to CBV | **15,790 cases** <br> All cases received a mailed notice with CBV link. Of those 15,790 cases, some received: <br>  - Email with link to notice in client portal (2,541) <br>  - Text message with CBV link (13,542) |
| Total number of Income Reports submitted | **894 Income Reports** |
| Number Income Reports with a W2 job | **871** (97.43% of Income Reports) |
| Number of Income Reports with an app-based gig job       | **20** (2.23% of Income Reports)             |
| Number of Income Reports with both W2 and app-based gig job      | **5** (0.56% of Income Reports)              |

### 

### 

### Hypothesis results

| Hypothesis          | Result        | Explanation                    |
| ------------- | --------------------- | ------------------------------- |
| CBV will provide **recent** income data. | **Validated** | 85% of jobs included in CBV Income Reports had income data from the last 14 days. |
| CBV will provide **accurate** income data.    | **Partially Validated**   | Case reviews done by the state agency and sentiments from the front-line staff survey suggest CBV data was accurate, complete, and easy to index, but more detail is needed. |
| CBV will provide **complete** data for income verification.    | **Partially Validated**   | Case reviews done by the state agency and sentiments from the front-line staff survey suggest CBV data was accurate, complete, and easy to index, but more detail is needed. |
| CBV’S Income Report will be easy to index to the **right person and case. | **Partially Validated**   | Case reviews done by the state agency and sentiments from the front-line staff survey suggest CBV data was accurate, complete, and easy to index, but more detail is needed. |
| CBV will verify income **without additional client contact or RFIs.**     | **Partially Validated**   | Pilot metrics tracked cannot draw conclusive results on impact to cases and case outcomes. According to caseworker survey data, 77.7% reported they “rarely” or “never” needed additional information from clients.  |

## 1B) **Income data gathered by IVaaS CBV**

### How many jobs were included in the Income Reports?
![Chart displaying the number of Income Reports with 1 job, 2 jobs, and
3 jobs. A large blue bar shows 816 Income Reports contained 1 job. Large
blue text states \"91.3% of reports contaiend 1 job\". A smaller grey
bar shows 71 Income Reports contained 2 jobs. A very small grey bar
shows 7 Income Reports contained 3 jobs.
](/docs/product-updates/images/2025-10-17_Accounts_Connected.png)

- **The median Income Report contained 1 job.**

- **The highest number of jobs in an Income Report was 3 jobs.**

  - 7 (0.78%) of the 894 Income Reports had 3 jobs.

  - *Note: See Section 2: Client Experience for how number of jobs
    impacted time to complete CBV.*

### 

### How "fresh" or recent was the income data? 

- **85% of jobs included in IVaaS CBV Income Reports had income data
  from the last 14 days.**

  - 14% of these jobs had a pay date in the last 2 to 4 days.

  - 47% of these jobs had a pay date in the last 4 to 8 days.

  - 10% of these jobs had a pay date in the last 8 to 12 days.

<!-- -->

- **Of the 15% of jobs that did not have income data from the last 14
  days:**

  - 6% had a pay date in the last 14 -- 90 days.

  - 9% did not have a pay date in the last 90 days (which can be used to
    prove termination from a job and loss of an income source)

<!-- -->

- **Payroll and gig platform accounts had sufficient data necessary for
  an income verification 99.5% of the time.**

  - Reasons an account might not meet the valid data threshold:

    - Payroll account does not contain the name of the employer making
      the payments

    - No gross income/net income but evidence of hours worked

*What income data was available was through IVaaS CBV?*

- **Hours Worked.** Hours worked was available **87.28%** of the time
  for W2 platforms and **97%** of the time for gig platforms.

  - In accounts that don't include hours worked, HR1 work requirements
    could be determined by dividing the hours worked by the federal
    minimum wage to create an estimate.

  - 97% of gig platform accounts connected include the hour duration of
    the gigs worked. The only gig platforms that did not return hours
    were Grubhub and Rover (2 people connected to these gig apps).

- Among the jobs connected that were included in an Income Report:

  - **Termination date** was included for **70.59% of jobs** that had an
    employment status other than "employed".

  - **Employer phone number** was provided for **98.65% of jobs.**

  - **Last 4 digits of Social Security Number (SSN)** was included for
    **87.09% of jobs**.\
    *\* This simply means that some payroll companies and many gig
    platforms did not record SSN. This does not mean that the applicant
    did not have an SSN.*

  - **Date of Birth** was included for **77.43% of jobs**.

*How did IVaaS CBV Income Report data compare to other verification
methods?*

*Note: Data shared in this section is based on 64 case reviews. The
state agency conducted these reviews to compare the Income Report to
Equifax's The Work Number and/or State Quarterly Wage Data.*

- **5.2% of all Medicaid cases that received a notice in May used IVaaS
  CBV to verify their income.**

  - 43% of all Medicaid cases that received a notice responded to the
    agency's request for income verification.

- **IVaaS CBV Income Reports verified income for 85.7% of the cases
  reviewed.** 54 of the 64 cases reviewed used the CBV Income Report to
  verify income for the case.

  - 

- **In comparing the IVaaS CBV Income Report to Equifax's TWN and/or
  State Quarterly Wage Data, the agency found 10 cases where data
  differed.**\
  *Of the 64 cases reviewed:*

  - **10 cases that submitted CBV Income Reports provided different
    income data.** *Note: The team is working with the State agency to
    get more details on additional discrepancies.*

    - **In 2 cases CBV showed no recent payments from the employer.** In
      both of these cases, the client added a comment to their CBV
      Income Report stating that the payment data was inaccurate.

      - In 1 of the cases, The Work Number showed consistent biweekly
        income.

      - In 1 of the cases, Quarterly Wage Data showed earnings in the
        second quarter of the year.

    - **In 1 case CBV was missing payments**. 2 payments but missed 3
      additional payments. The Work Number showed all 5 payments.

## 1C) IVaaS CBV Coverage

- **IVaaS CBV provided a high search coverage rate. 99% of searches
  returned at least one search result.**

  - **IVaaS CBV did not return search results for 71 of 7,330 searches
    (0.97% of searches).** This means while clients conducted a search,
    the term they searched resulted in zero employers, payroll
    providers, or gig apps.

    - 28 searches were unknown characters or numbers.

    - 14 searches were local restaurants, insurance brokers, or LLCs.

    - 2 searches were for a State agency acronym.

    - 8 searches were for websites (6 were for the same restaurant, 2
      were for a payroll website).

    - 1 search was for "just started a new job have not got paid yet"

    - 1 search was for "Walmart" but included a specific address.

    - 17 searches were unknown acronyms or employers.

- **Of the 7,259 searches (99.03%) that did return results:**

  - More than 5 results were displayed in 88.62% of searches.

  - Between 1 to 5 results were displayed in 10.41% of searches.

- **The most common search queries were:**

  - Walmart

  - UKG

  - Ochsner

  - Unemployed

  - Dollar General

# Section 2: **Client experience**

## 2A) **Overview**

This section provides details on the experience clients had with IVaaS
CBV in Pilot C for Medicaid. The data in this section pulls from CBV
product metrics and 5 survey responses.

![There are two separate visuals. One says \"894 Income Reports\" and
below is a small light blue horizontal bar that says \"25 app-based gig
workers\". Right next to that is a darker blue horizontal bar that says
\"871 W2 workers.\" The second visual shows a line with 1 minute at the
left and 16 minutes at the right. In large navy blue text, it says \"6
minutes 39 seconds median time it took users to complete CBV\" which is
tied to a blue square plotted along the 1 - 16 minute line. There are 3
light blue squares showing the median time for users who connected 1 job
(6 min 28 sec), 2 jobs (10 min 30 sec), and 3 jobs (14 min 43 sec).
](/docs/product-updates/images/2025-10-17_Topline_Metrics.png)

**2B) Time to complete IVaaS CBV**

- **Among the successful reports submitted** (n = 894)**, it took the
  median client 6.65 minutes** **to complete IVaaS CBV.**

  - 90% of clients who submitted an Income Report completed the IVaaS
    CBV flow in 15.53 minutes or less.

  - 10% of clients who submitted an Income Report completed the IVaaS
    CBV flow in 3.6 minutes or less.

![Histogram of time to complete IVaaS CBV in minutes with a peak at 4 minutes.](/docs/product-updates/images/2025-10-17_Session_Time.png)

- **The number of jobs a client connected to impacted time to
  complete:**

  - Median completion time for **1 job**: **6.47 minutes**

  - Median completion time for **2 jobs**: **10.5 minutes**

  - Median completion time for **3 jobs:** **14.72 minutes**

## 2C) **Client engagement and adoption**

### How were clients introduced to IVaaS CBV? 

About one day after the state system determined the beneficiary was
presumptively over income according to state Quarterly Wage Data, the
state Medicaid system sent out:

- **A paper notice via mail with a generic link to CBV.**

  - *For cases enrolled in email notices:* Email notice linked
    beneficiaries to the client portal with an online version of the
    paper notice.

  - *For cases enrolled in SMS:* A text message (SMS) with a generic
    link to CBV.

> **SMS / Text Message:**\
> "\[State\] Medicaid: To maintain your coverage, you need to report
> your income. Please report your income here: ReportMyIncome.org.
> Deadline: \[Date\]. For questions, call 1-888-342-6207. Reply STOP
> to end texts.\"

Beneficiaries enrolled in text messages who had not responded to the RFI
also received a reminder text message on May 24, 2025. This text did not
contain a link to CBV. 

### Who used IVaaS CBV?

Across the 894 Income Reports:

- Most clients (66%) were between the ages of 19 and 49.\
  *Note: This data is derived from payment platforms when date of birth
  is available after the client successfully logged into an account.*

- 97.43% of Income Reports contained a W2 job.

- 2.8% of Income Reports contained a gig job.

- English was used in 99.56% of IVaaS CBV sessions.

- Spanish was used in 0.51% of IVaaS CBV sessions.\
  *Note: This State has a small population of Spanish speakers.*

![A bar graph shows the ages of CBV users. In large blue text at the top
it says \"66% of users were between 19 and 49 years of age\". The age
brackets and number of users are listed below: 18 or younger = 19 users
19-25 = 170 users 26-29 = 117 users 30-39 = 198 users 40-49 = 146 users
50-59 = 53 uesrs 60-64 = 16 users 65 and older = 2
users](/docs/product-updates/images/2025-10-17_Age_distro.png)

### What devices did clients use to access IVaaS CBV?

*Note: Data shared in this section is based on sessions, not on unique users or even devices. Subsequent pilots will have better tracking capabilities.* 

| Device      |      Number of sessions    |  Percent of all sessions |
|  ----------------- | ----------------------- | ------------------------------ |
|  **Mobile**    |    **13,711**         |     **84.17%** |
|  **Tablet**    |    35            |          0.22% |
|  **Desktop**   |    2,427         |          14.9% |

### How many clients were able to submit an Income Report? Where did clients drop off? 

*Note: Data shared in this section is based on sessions, not on unique
users or even devices. Subsequent pilots will have better tracking
capabilities.*


### **Conversion and drop-off across IVaaS CBV steps**
| \#                | Step              | Explanation          | Number of interactions         | Percent conversion from previous step          |
| ------------------- | ------------------- | ---------------------- | ------------------- | ------------------- |
| **1**             | **Received a link to IVaaS CBV** | *Clients who were sent a link to CBV by the agency.*    | 15,790            | \-                |
| **2**             | **Clicked IVaaS CBV link**   | *Number of times the link was clicked* | 16,285            | \-                |
| **3**             | **Consented and viewed search page**   | *Number of times consent terms were agreed to and continued to next page.*     | 5,354             | **32.88%**        |
| **4**             | **Opened login modal**    | *Found an employer or platform and clicked on it.*   | 3,395             | **63.41%**        |
| **5**             | **Attempted login**       | *Entered username and password on a platform to attempt logging in.*   | 2,082             | **61.33%**        |
| **6**             | **Login succeeded**           | *Successfully entered login credentials to their platform.*        | 1,141             | **54.8%**         |
| **7**             | **Viewed payment details**  | *Reviewed the income data IVaaS CBV pulled from the platform they logged into.* | 1,074             | **94.13%**        |
| **8**             | **Entered indexing details**         | *Because the link was generic, the client needed to enter date of birth. They also had the option to enter their case number.*    | 930               | **86.59%**        |
| **9**             | **Submitted report**       | *Consented to legal agreement and submitted income data.*  | 894               | **96.12%**        |

**Observations about engagement and drop-off:**

- Half of the sessions that attempted log-in succeeded (54.8%).

- 78.35% of the sessions that made it through log in (n=1,141) submitted
  a report (n=894).

- The most significant session drop-off is on the first two pages before
  searching for an employer (32.88% of sessions converted from viewing
  the entry page to viewing the employer search page).

  - This could be attributed to people clicking the link and deciding to
    come back and finish the process later. Future pilots will track
    distinct user devices instead of sessions.

- There is a notable drop-off when users are asked to enter indexing
  details (i.e. clients needed to provide their date of birth and could
  optionally provide their case number). Of the 930 sessions who could
  have submitted an Income Report without this page, 36 sessions dropped
  off (13.41%).

**Hypotheses about drop-off:**

- There is a large amount of drop-off in sessions between Viewing the
  IVaaS CBV entry page and moving onto the employer search page because:

  - Users are opening the link multiple times before proceeding.

  - Users are opening the link when they receive the text or notice,
    then leaving.

  - Users do not want to use CBV or are unsure what it is.

- Switching to a tokenized link would increase submission rates by
  removing the additional step of users entering indexing information.

![Screenshot of the IVaaS CBV search experience](/docs/product-updates/images/2025-10-17_Employer_Search.png)

### How did clients search for and find platforms?  
**Clients have four ways of finding their payroll or gig platform when they use IVaaS CBV:**  Option 1 and 2: The employer search page provides common payroll providers and app-based employers which clients can click on and immediately begin logging in.  Option 3: If they know the name of their payroll provider and it is not listed, they can search for it.  Option 4: If they do not know their payroll provider, they can search by their employer name and the search results will take them to the payroll provider for that employer. 

## **Searching for and identifying payroll and app-based gig platforms**
| Search method | Number of interactions      | Percent of all interactions | Number of successful logins      | Percent of search method that were successful at logging in     |
| ---------------- | ---------------- | ---------------- | ---------------- | ---------------- |
| **Clicked on platform icon** - Payroll provider icon | 1,318          | 38.9%          | 495            | 37.56%         |
| **Clicked on platform icon** - App-based gig platform icon | 65             | 1.91%          | 34             | 52.31%         |
| **Used search bar**             | 2,006          | 59.19%         | 607            | 30.3%          |
**Observations about searching for platforms:**

- **The majority of sessions used the search bar, but this resulted in
  the lowest login success rate** (30.3% of these searches resulted in
  successful login).

  - When the app-based gig platform tile was used, it resulted in more
    successful logins (52.31% of these logins were successful).

- **The search experience is not designed well for individuals who have
  had recent job loss or are currently unemployed.**

  - *"Unemployed"* was searched for 50 times.

  - *"None"* was searched for 29 times.

  - *"Unemployment"* was searched for 5 times.

  - *"Not employed"* was searched for 4 times.

  - *"N/a"* was searched for 2 times.

  - *"None"* was searched for 2 times.

  - *"Na"* was searched for 2 times.

  - *"Not employed"* was searched for 2 times.

  - *"No employer"* was searched for 2 times.

  - *"I'm unemployed"* was searched for 1 time.

  - *"Unemployment insurance benefits"* was searched for 1 time.

  - *"NOT EMPLOYED"* was searched for 1 time.

  - *"Don't have one"* was searched for 1 time.

- **Some clients are trying to use IVaaS CBV to search and log into
  their social security benefits, which is currently not supported since
  it is unearned income.**

  - *"Social Security"* or a similar wording was searched 7 times.

  - *"SSDI"* or similar wording was searched 6 times.

- **In sessions where an Income Report was submitted, clients searched
  fewer times.**

<!-- -->

- In sessions where a report [was]{.underline} submitted, clients
  searched 1.59 times.

- In sessions where a report was [not]{.underline} submitted, clients
  searched 2.37 times.

![A comparison of a graph of median number of searches for sessions where a report was submitted vs those that did not.](/docs/product-updates/images/2025-10-17_Search_Metrics.png)

### How did clients troubleshoot or seek help content?

**The help modal was opened 615 times, primarily from the help banner**
(n=404 or 66% of all help modal openings) that is displayed when clients
close the login modal and return to the search page.

![A screenshot of the help modal banner alert that is shown when someone closes a login modal without connecting successfully .](/docs/product-updates/images/2025-10-17_Help_Modal.png)

  -----------------------------------------------------------------------
  | Help Topic | Number of sessions that selected & viewed help topic |   Percent of all sessions that viewed a help topic |
  | ------------------------ | ------------------------- | --------------------|
  | **Payroll Provider** <br> *I don’t know my payroll provider* |   176        |               24.44% |
  | **Employer** <br> *I can’t find the correct employer* |           159         |              22.1% |
  | **Login Credentials Discomfort** <br> *I don’t feel comfortable entering my login credentials* |     119    |                   16.52% |
  | **Username** <br> *I don’t know my username* | 100          |             13.89% |
  | **Password** <br> *I don’t know my password* |         70         |               9.72% |
  | **Company ID** <br> *I don't know my company ID* |       96           |             13.33% |

**Observations about help modal views:**

- 13 of the 894 Income Reports were submitted after viewing a help
  topic.

- Only 4% of session who viewed a help topic (n = 328) successfully
  submitted an Income Report (n = 13).

- The most common help topics viewed (collectively 46.54%) are related
  to finding an employer or identifying a payroll provider, which could
  explain reasons for drop-off earlier in the IVaaS CBV experience.

- The second most common help topics (collectively 36.95%) are related
  to login challenges.

- Discomfort entering login credentials (16.52% of views) could also
  explain some of the drop-off early in the IVaaS CBV experience.

### 

### How did clients feel about IVaaS CBV? What feedback did they provide?

Only 5 clients filled out the IVaaS CBV survey in this pilot. The low
number of responses prompted the team to redesign the survey and the
parts of the IVaaS CBV website that link to this survey. Below are the 5
client responses the team received:

- **Difficulties logging in**

> *"I\'m trying to share my payroll data through my employer, and I\'m
> allowed to enter my work email and password, but when I get an SMS
> message with the verification code every time I put it in it says \'an
> unexpected error occurred."*

- **Confusion about what to do if recently unemployed**

> *"None of these are letting me report my income I used Gusto and am
> now unemployed"*

- **Unclear**

> *"I don't know"*

- **Positive experiences**

> *"Good experience so far."*
>
> *"Simple and to the point"*

# Section 3: **Eligibility Worker & Agency Staff Experience**

## 3A) **Overview**

Because Income Reports were sent via encrypted email to the state
agency's existing inbox, a specialist needed to index Income Reports to
the correct case for an Eligibility Worker to review.

## 3B) **Caseworker Sentiment**

- **CBV's Income Report provides robust, recent income data to
  caseworkers which eases and speeds up the income verification
  process.**\
  *In Pilot C, 139 caseworkers completed a survey after the pilot
  concluded. In that survey, caseworkers said it was:*

  - **Easier to verify income using IVaaS CBV:** 79% agreed or strongly
    agreed

  - **Faster to verify income using IVaaS CBV:** 80% agreed or strongly
    agreed

  - **More complete information using IVaaS CBV:** 73% agreed or
    strongly agreed

<!-- -->

- **In the majority of cases, caseworkers said IVaaS CBV's Income Report
  verified income without additional information.**

  - **77.7%** of caseworkers reported **never or rarely needing
    additional information.**

  - **18%** of caseworkers reported **sometimes needing additional
    information.**

  - **4.3%** of caseworkers reported **often needing additional
    information.**

> *"CBV makes it so much easier to able to locate the information you
> need, enter it, and be able to move on to other things."*\
> \
> *"I spent more time entering the income because it was provided for 90
> days. It took more time away from other tasks but it will be
> beneficial in the future because with will have more months of actual
> income which shows a complete picture of yearly income."*\
> \
> *"I spent the same amount of time working these tasks as regular
> paystub tasks."*
>
> *"The CBV is a good app but it does not give us information about VA
> pensions and other pensions/retirements that is received by the
> client."*
>
> *"Less time gathering and looking for stubs \[paystubs\]"*\
> \
> *"A lot of times members will self-attest to their net income and will
> send screenshots of their take home pay as opposed to their gross
> income. Using CBV, I don\'t have to contact the client to request
> their gross income which results in fewer overdue tasks due to waiting
> on the client to respond."*
>
> *"It was very nice not having to mentally calculate whether it was a
> biweekly or weekly payment. It was extremely nice that you spend less
> time examining the check stub to make sure you find the correct hours
> worked, pre-tax deductions, the employer (listed or not), and the
> gross amount. Everything you need is in an easy to read format making
> the flow of inputting this information into an income worksheet
> smoother and quicker."*

- **Caseworkers reported that IVaaS CBV Income Reports always or usually
  matched other income sources.**

  - **35.3%** of caseworkers reported that Income Reports they reviewed
    **always matched** other income verification sources.

  - **44.6%** of caseworkers reported that Income Reports they reviewed
    **usually matched** other income verification sources.

  - **18.0%** of caseworkers reported that Income Reports they reviewed
    **sometimes** matched other income verification sources.

  - **2.2%** of caseworkers reported that Income Reports they reviewed
    **rarely** matched other income verification sources.

#### 3C) **Other State Staff Sentiment**

- **Staff reported that indexing CBV Income Reports was easy or very
  easy.**\
  *In Pilot C, 13 staff who match submitted documents to the correct
  case completed a survey after the pilot concluded. In that survey,
  caseworkers said it was:*

  - **61.5%** reported indexing Income Reports was **very easy**.

  - **23.1%** reported indexing Income Reports was **easy**.

  - **15.4%** reported indexing Income Reports was **neither easy nor
    difficult**.

- **Compared to other income documents submitted, IVaaS CBV Income
  Reports were slightly easier to index to the correct case.** Among
  staff who filled out the survey:

  - 53.8% reported that it was easier to associate metadata from the CBV
    Income Report compared to other income documents.

  - 46.2% reported there was no difference for them.

> *\" It was neatly typed which was a huge help. All information was in
> the same place which made it a bit easier to find the information for
> quick reference."*\
> \
> *"Information is clear and detailed"*

- **3 staff reported having issues indexing IVaaS CBV Income Reports to
  the correct case.**

> *"If the last 4 digits of social security number was not included it
> was harder to associate the metadata. It was even harder to locate
> clients when last name was different in our system. It would be
> helpful if SSN/case number is included in the report."*
>
> *"There are 2 of the CBV I could not find the person. Then something
> the person did not list the right name on the case. They have more
> than one name. They go by maiden name and the did CBV is in the
> married name. Need to make sure they list last 4 of SSN and DOB and
> name on the case and let us know that they are married."*\
> \
> *"Some forms did not include a SSN or DOB, and it was a bit of work to
> match other information."*

- **Call center staff were able to identify key questions Medicaid
  clients had about the IVaaS CBV pilot.**

  - Concerns about the text message or link being a scam:

> *"Client asked if the link was for Medicaid. Was concerned it was from
> hackers."*\
> \
> *"Most clients called to verify that we sent the link."*\
> \
> *"Was it real." \[i.e. Clients called to find out if the link to IVaaS
> CBV was legitimate or not\]*\
> \
> *"Most members wanted to know if Medicaid sent the text."*
