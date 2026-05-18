---
name: interacting-with-jira
description: Interacting with Jira to view a ticket, list my tickets, etc.
---

Jira ticket/issue numbers are of the format "FFS-1234". When commands use the variable "$issue", insert this value.

When commands use the variable "$ME", insert the user's Jira username.

# Common commands

| Task          | Command                       |
|---------------|-------------------------------|
| Get my username | jira me |
| View an issue | jira issue show FFS-4071 |
| Start an issue | jira issue move "$issue" "In Progress" -a"$ME" |
