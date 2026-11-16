After a failed income report or activity delivery, Emmy retries up to five additional times. The waits
between attempts are 5 minutes, 10 minutes, 30 minutes, 1 hour, and 4 hours.

For combined income JSON and PDF delivery, a PDF retry does not resend the JSON
report when JSON delivery has already succeeded.

For combined activity JSON and document delivery, Emmy sends the CE Activity
Report JSON first. If the JSON request fails, Emmy sends no documents on that
attempt. After the JSON succeeds, Emmy sends each uploaded document and the
activity report PDF. If a document request fails, the retry does not resend the
JSON. It resends every activity document, including the report PDF, with the
same `X-IVAAS-Document-Id` and filename. See [Documents](#tag/documents).

If the final attempt fails, the job remains failed for investigation by the Emmy
team in partnership with your agency's technical team.