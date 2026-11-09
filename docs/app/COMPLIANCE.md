# Compliance artifacts

To meet future compliance requirements, we maintain a PDF representation of our data model. We formerly had an infrastructure diagram too, which could be resurrected from git if needed.

## Documents

### Logical Data Model

The logical data model will be auto-generated on each database migration.
The rendered output is saved to docs/app/rendered/database-schema.pdf.

## Generated report PDFs (FFS-4894)

Application PDFs use `PdfRenderer`: Grover/Puppeteer renders semantic HTML into
Chromium's tagged PDF, which is returned unchanged. PDF generation does not use
Python or pypdf. Chromium's native tags, document outline, title, and language
are retained. No post-processing adds PDF/UA identification metadata, normalizes
structure roles or list bodies, or marks remaining untagged content as artifacts.
This setup evaluates Chromium's native accessibility output; PDF/UA-1 validation
may fail and the output does not claim PDF/UA compliance.
Changes to PDF templates must retain accessible
DOM content and be checked against the final PDF; hiding meaningful HTML with
`aria-hidden` also hides it from the PDF's accessibility tree.

The renderer embeds application CSS, fonts, and images. A PDF-specific Content
Security Policy prevents remote resource requests. PDFs contain a title and
language, tagged headings and table cells, and alternative text for agency logos.
JSON output and event tracking are unchanged.

### Local setup and automated validation

From `app/`, `bin/setup` installs the dependencies. For an existing checkout:

```sh
bundle install
npm ci
```

Puppeteer installs its matching Chrome browser locally and in CI. Docker uses
Debian Chromium (including arm64) and a Node version matching `.node-version`.
`PUPPETEER_EXECUTABLE_PATH` can select a system browser.
Docker/CI explicitly disable Chromium's OS sandbox because those container
runtimes do not provide Chrome's required sandbox support; Chrome runs as the
application's non-root user in the release image. Local runs retain the sandbox.

Install Java 21 and veraPDF, then generate and validate synthetic test reports:

```sh
ruby bin/install-verapdf /tmp/emmy-verapdf
PDF_ACCESSIBILITY_OUTPUT_DIR="$HOME/.local/share/emmy/pdf-accessibility/pdfs" bundle exec rspec \
  spec/services/pdf_renderer_spec.rb \
  spec/services/pdf_service_spec.rb \
  spec/services/transmitters/activity_s3_transmitter_spec.rb \
  spec/controllers/activities/submit_controller_spec.rb \
  spec/controllers/cbv/submits_controller_spec.rb \
  spec/mailers/caseworker_mailer_spec.rb
VERAPDF=/tmp/emmy-verapdf/verapdf bundle exec ruby bin/check-pdf-accessibility \
  "$HOME/.local/share/emmy/pdf-accessibility/pdfs"
```

The validator writes `verapdf.xml` under `~/.local/share/emmy/pdf-accessibility`
(or `PDF_ACCESSIBILITY_REPORT_DIR` when set) and fails on any noncompliant
document, parse error, or missing report.
The RSpec CI job validates all exported PDFs and uploads the synthetic PDFs and
`verapdf.xml` in the `pdf-accessibility` artifact. Exporting reports is a test-only
facility; do not export real beneficiary data into CI artifacts. Passing veraPDF's
machine-checkable PDF/UA-1 rules does not establish complete Section 508 compliance.
Manual reading-order, accuracy, contrast, and assistive-technology checks remain
required. See [veraPDF validation scope](https://docs.verapdf.org/validation/).
