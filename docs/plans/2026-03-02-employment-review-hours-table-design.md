# Employment Review Page: Hours & Income Table

## Summary

Add a "Hours and income" section to the employment self-attestation review page, displaying monthly gross income and hours worked in a stacked table. This mirrors the community service review page's hours table pattern but adds a gross income row per month.

## Design

### Layout

Between the employer info table and additional comments form, add:

1. An h2 section heading ("Hours and income") with no edit link (editing is per-month)
2. A stacked `TableComponent` with one group per reporting month containing:
   - A subheader row with the month name and an "Edit" link
   - A "Gross income" row showing the dollar amount
   - A "Hours worked" row showing the hour count

### Edit Flow

Each month's "Edit" link routes to `edit_activities_flow_income_employment_month_path` with `from_review: 1`. The existing `MonthlyHoursInput` concern handles returning the user to the review page after saving.

### Files Changed

- `app/views/activities/employment/review.html.erb` — add hours/income table section
- `app/config/locales/en.yml` — add i18n keys under `activities.employment.review`

### New i18n Keys

```yaml
activities:
  employment:
    review:
      hours_and_income: Hours and income
      gross_income: Gross income
      hours_worked: Hours worked
```

### No Changes Needed

Controller, routes, models, and shared components are already in place.
