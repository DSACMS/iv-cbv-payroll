# Client agency configuration

Agency settings are defined in [client-agency-config.yml](../../app/config/client-agency-config.yml).

## Invitation lifetime and reuse

- `invitation_valid_days` controls how many days a new invitation remains valid. Invitations expire at the end of that day in Eastern Time.
- `allow_activity_invitation_reuse` is a boolean controlling reuse of tokenized Emmy CE and Emmy Employment links after submission. It defaults to `true` when omitted. Louisiana sets it to `false`. Emmy Income invitations and generic links are unaffected.

When reuse is disabled, an invitation is considered used once an associated report has been completed and queued for delivery. Completion and queueing occur in one database transaction; a queueing failure rolls back completion. Delivery delays, failures, and retries do not make the invitation usable again.

Reopening a used link, or continuing an older session associated with it, shows the existing link expiration page. The submitted report's success page and download remain available in its existing session. No new report fields are added to JSON or PDF output: the existing completion timestamp supplies the used-link state.
