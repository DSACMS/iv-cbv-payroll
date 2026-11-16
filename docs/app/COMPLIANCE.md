# Compliance artifacts

To meet future compliance requirements, we maintain a PDF representation of our data model. We formerly had an infrastructure diagram too, which could be resurrected from git if needed.

## Documents

### Logical Data Model

The logical data model will be auto-generated on each database migration.
The rendered output is saved to docs/app/rendered/database-schema.pdf.

## Generated report PDFs (FFS-4894)

Application PDFs use `PdfRenderer` to return Grover/Puppeteer's native Chromium
PDF output. Tagged PDFs and document outlines are enabled. Accessibility comes
from the HTML source: retain semantic headings, table headers, document titles,
language, and alternative text for meaningful images. Decorative text separators
use CSS borders, and visual bold labels use styled spans to avoid Chromium's
unmapped emphasis roles. Hiding meaningful HTML with `aria-hidden` also hides it
from the PDF's accessibility tree.

There is no PDF post-processing or PDF/UA conformance metadata declaration.
Chromium's untagged decorations, pagination footers, and missing XMP metadata can
still fail PDF/UA validation. Native tagging does not establish full compliance
or resolve the reported Preview/VoiceOver navigation-order issue.

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
(or `PDF_ACCESSIBILITY_REPORT_DIR` when set) and fails on unexpected rule violations, validator errors, or missing/incomplete
results. The four accepted native Chromium rule failures are listed below; they
remain visible in the XML evidence and do not establish PDF/UA compliance.
The RSpec CI job validates all exported PDFs and uploads the synthetic PDFs and
`verapdf.xml` in the `pdf-accessibility` artifact. Exporting reports is a test-only
facility; do not export real beneficiary data into CI artifacts. Passing veraPDF's
machine-checkable PDF/UA-1 rules does not establish complete Section 508 compliance.
Manual reading-order, accuracy, contrast, and assistive-technology checks remain
required. See [veraPDF validation scope](https://docs.verapdf.org/validation/).

### Known native Chromium limitations

A local veraPDF 1.30.3 audit of 21 synthetic PDFs exported by the renderer,
income report, activity report, activity transmitter, and activity submit specs
found these PDF/UA-1 failures. All 38 RSpec examples passed; all 21 generated
PDFs parsed successfully but failed validation.

| Rule (clause / test) | Observed failure | Accessibility implication |
| --- | --- | --- |
| 7.1 / 3 | Untagged content in all 21 PDFs (160 checks) | Content is neither in the structure tree nor explicitly marked as decorative. Meaningful content could be skipped or read inconsistently; inspect the affected content and reading order manually. |
| 7.1 / 8 | Missing XMP metadata in all 21 PDFs | Fails the document metadata requirement. This alone does not mean the text is unreadable with assistive technology. |
| 7.1 / 5 | Unmapped `Strong` role in the renderer stress fixture | PDF/UA-1 readers cannot rely on a standard role for emphasis. Report templates use CSS for visual bold labels to avoid this Chromium mapping issue. |
| 7.2 / 20 | A direct paragraph child of `LI` in the renderer stress fixture | The list lacks the required `LBody` grouping, which can impair consistent list navigation. |

The last two failures occurred in the renderer's synthetic HTML example, not the
application report PDFs in this sample. A subsequent fixture update replaced the
list item's paragraph with a block span using the same margins. Before/after
screenshots were identical, and a new veraPDF run confirmed that 7.2 / 20 no
longer fails. Replacing the fixture's `strong` element with a bold-styled span
also preserved identical screenshots and removed the 7.1 / 5 failure. Only
untagged content (7.1 / 3) and missing XMP metadata (7.1 / 8) remained in that fixture
with native Chromium output. The fixture's decorative text separator has since
been replaced by a CSS border, matching the report-template approach.
The deliberately mocked PDF in the renderer unit test is
excluded from export; actual generated PDFs are always validated.

The veraPDF CI gate accepts ISO 14289-1:2014 rules 7.1/3, 7.1/8, 7.1/5, and
7.2/20 as expected native Chromium failures. All other failed rules still fail
the job. These exceptions apply to all generated reports, regardless of failure
counts; newly introduced issues within those four rules require manual review. A screen-reader review is still needed to
establish the practical impact on reading order, tables, lists, and report content.
In particular, the reported Preview/VoiceOver navigation-order issue is not fixed
by adding metadata or marking decorations as artifacts.
