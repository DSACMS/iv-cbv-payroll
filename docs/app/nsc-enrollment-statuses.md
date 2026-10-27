# NSC enrollment statuses

`NscDataFetcherService::ENROLLMENT_STATUSES` maps raw NSC enrollment codes to
the string enum stored on `NscEnrollmentTerm`.

| Raw code | Meaning | Stored status |
| --- | --- | --- |
| F | Full-time enrollment | `full_time` |
| Q | Three-quarter time enrollment | `three_quarter_time` |
| H | Half-time enrollment | `half_time` |
| L | Less than half-time enrollment | `less_than_half_time` |
| Y | Enrollment status not released by school | `enrolled` |
| A | Leave of absence | `leave_of_absence` |
| W | Withdrawn | `withdrawn` |
| S | Clearinghouse generated withdrawn | `withdrawn` |
| G | Graduated | `graduated` |
| D | Deceased | `deceased` |

The existing `enrolled` key is retained for compatibility with stored records.
Its display label describes the meaning of Y. Unrecognized codes are logged and
stored as `unknown`. Only F, Q, and H establish half-time-or-above enrollment;
the other statuses do not establish qualifying enrollment by themselves.

## Deduplication

Deduplication happens within each fetched response, after filtering to current
enrollment details and terms overlapping the reporting window, and after mapping
raw status codes to stored statuses. Records match when all persisted enrollment
attributes match: school name, student first/middle/last name, term begin/end
dates, and grouped enrollment status.

Consequently, otherwise identical W and S records produce one `withdrawn` term.
Certification dates do not make separate records; this version of the model does
not store them. Different grouped statuses, schools, student names, or term dates
remain separate records. Grouping does not select one status over another for a
term, and does not remove existing records from earlier fetches.

This checkout has no separate withdrawal flag or column, so no removal migration
is required. Existing `unknown` records cannot be reclassified without the raw
NSC response; this change applies the expanded mapping to future fetches.
