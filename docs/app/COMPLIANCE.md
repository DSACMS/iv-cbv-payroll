# Compliance artifacts

To meet future compliance requirements, we maintain a PDF representation of our data model. We formerly had an infrastructure diagram too, which could be resurrected from git if needed.

## Documents

### Logical Data Model

The logical data model will be auto-generated on each database migration.
The rendered output is saved to docs/app/rendered/database-schema.pdf.

## Generated report PDFs (FFS-4894)

Application PDFs use `PdfRenderer`: Grover/Puppeteer renders semantic HTML into
Chromium's tagged PDF, then `lib/pdf/finalize.py` completes PDF/UA-1 metadata and
structure using pypdf. It preserves existing marked-content IDs, text, and reading
order; maps Chromium's PDF 2.0 emphasis roles to PDF 1.7 spans; groups list-item
bodies; and marks untagged decoration, explicitly hidden DOM content, and running
page furniture as artifacts. This finalizer is only for trusted application HTML,
not for repairing uploaded PDFs. Changes to PDF templates must retain accessible
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
python3 -m venv "$HOME/.local/share/emmy/pdf-venv"
"$HOME/.local/share/emmy/pdf-venv/bin/python" -m pip install --require-hashes -r lib/pdf/requirements.txt
```

The Python requirements pin versions and SHA-256 hashes of universal wheels,
including `typing_extensions` for Python versions below 3.11. When updating a
dependency, verify its wheel against the official PyPI release and update its
version and hash together. Source distributions are not installed.

Puppeteer installs its matching Chrome browser locally and in CI. Docker uses
Debian Chromium (including arm64), a Node version matching `.node-version`, and
the same Python dependency. `PUPPETEER_EXECUTABLE_PATH` can select a system browser;
`PDF_PYTHON` can select another Python environment containing the pinned pypdf.
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
