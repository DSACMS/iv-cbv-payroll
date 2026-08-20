import { describe, beforeEach, afterEach, it, expect, vi } from "vitest"
import DocumentUploadController from "@js/controllers/document_upload_controller"
import fileChecksum from "@js/utilities/file_checksum"

const CHECKSUM = "n4bQgYhMfWWaL+qgxVrQFaO/TxsrC4Is0V1sFbDwCgg="

vi.mock("@js/utilities/file_checksum", () => ({ default: vi.fn() }))

const MAX_FILE_SIZE = 25 * 1024 * 1024
const TOO_LARGE = "Each file must be smaller than 25 MB."
const UNSUPPORTED = "Select a PDF, PNG, JPG, or HEIC file."
const FAILED = "We could not upload that file."

const setFiles = (input, files) =>
  Object.defineProperty(input, "files", { value: files, configurable: true })

const buildFile = (name, type, size) => {
  const file = new File(["x"], name, { type })
  Object.defineProperty(file, "size", { value: size })
  return file
}

const jsonResponse = (body, status = 200) => ({
  ok: status >= 200 && status < 300,
  status,
  json: () => Promise.resolve(body),
  text: () => Promise.resolve(JSON.stringify(body)),
})

const s3Response = (status, code) => ({
  ok: status >= 200 && status < 300,
  status,
  json: () => Promise.reject(new Error("not json")),
  text: () => Promise.resolve(`<?xml version="1.0"?><Error><Code>${code}</Code></Error>`),
})

const presignedUploadFor = (filename, signedId) => ({
  filename,
  url: "https://bucket.s3.amazonaws.com",
  fields: { key: `key-for-${filename}`, policy: "signed-policy" },
  signed_id: signedId,
})

describe("DocumentUploadController", () => {
  let input

  const flush = () => new Promise((resolve) => setTimeout(resolve, 0))

  beforeEach(() => {
    document.body.innerHTML = `
      <form
        data-controller="document-upload"
        data-document-upload-presign-url-value="/activities/presigned_uploads"
        data-document-upload-max-file-size-value="${MAX_FILE_SIZE}"
        data-document-upload-allowed-types-value="image/*,application/pdf"
        data-document-upload-heading-template-value="Uploaded documents (%{count})"
        data-document-upload-remove-label-value="Remove file"
        data-document-upload-icon-href-value="/assets/sprite.svg#file_present"
        data-document-upload-error-too-large-value="${TOO_LARGE}"
        data-document-upload-error-unsupported-type-value="${UNSUPPORTED}"
        data-document-upload-error-upload-failed-value="${FAILED}"
      >
        <div hidden data-document-upload-target="signedIds"></div>
        <div class="document-uploads" hidden data-document-upload-target="listSection">
          <h2 data-document-upload-target="listHeading"></h2>
          <ul data-document-upload-target="list"></ul>
        </div>
        <input type="file" multiple
               data-document-upload-target="input"
               data-action="change->document-upload#select">
        <div class="usa-error-message" hidden data-document-upload-target="error"></div>
        <input type="submit" value="Continue">
      </form>
    `

    fileChecksum.mockImplementation(() => Promise.resolve(CHECKSUM))

    window.Stimulus.register("document-upload", DocumentUploadController)
    input = document.querySelector("input[type=file]")
  })

  afterEach(() => {
    document.body.innerHTML = ""
  })

  const selectFiles = async (...files) => {
    setFiles(input, files)
    input.dispatchEvent(new Event("change", { bubbles: true }))
    await flush()
  }

  const errorText = () => document.querySelector("[data-document-upload-target=error]").textContent
  const signedIdValues = () =>
    Array.from(document.querySelectorAll("[data-document-upload-target=signedIds] input")).map(
      (node) => node.value
    )
  const listItems = () => document.querySelectorAll("[data-document-upload-target=list] li")
  const submitButton = () => document.querySelector("input[type=submit]")

  it("uploads a selected file to the bucket and records a signed ID", async () => {
    fetch
      .mockResolvedValueOnce(
        jsonResponse({ uploads: [presignedUploadFor("verification.pdf", "signed-id-1")] })
      )
      .mockResolvedValueOnce({ ok: true, status: 204 })

    await selectFiles(buildFile("verification.pdf", "application/pdf", 1024))

    const [presignUrl] = fetch.mock.calls[0]
    const [uploadUrl, uploadOptions] = fetch.mock.calls[1]

    expect(presignUrl).toBe("/activities/presigned_uploads")
    expect(uploadUrl).toBe("https://bucket.s3.amazonaws.com")
    expect(uploadOptions.method).toBe("POST")
    expect(signedIdValues()).toEqual(["signed-id-1"])
    expect(listItems()).toHaveLength(1)
  })

  it("appends the file after every policy field", async () => {
    fetch
      .mockResolvedValueOnce(
        jsonResponse({ uploads: [presignedUploadFor("verification.pdf", "signed-id-1")] })
      )
      .mockResolvedValueOnce({ ok: true, status: 204 })

    await selectFiles(buildFile("verification.pdf", "application/pdf", 1024))

    const body = fetch.mock.calls[1][1].body
    const names = Array.from(body.keys())

    expect(names).toEqual(["key", "policy", "file"])
  })

  it("blocks Continue until the upload finishes, so the form cannot submit without the signed ID", async () => {
    let submitDisabledDuringUpload = null
    fetch
      .mockResolvedValueOnce(
        jsonResponse({ uploads: [presignedUploadFor("verification.pdf", "signed-id-1")] })
      )
      .mockImplementationOnce(async () => {
        submitDisabledDuringUpload = submitButton().disabled
        return { ok: true, status: 204 }
      })

    expect(submitButton().disabled).toBe(false)

    await selectFiles(buildFile("verification.pdf", "application/pdf", 1024))

    expect(submitDisabledDuringUpload).toBe(true)
    expect(submitButton().disabled).toBe(false)
    expect(signedIdValues()).toEqual(["signed-id-1"])
  })

  it("re-enables Continue when the upload fails", async () => {
    fetch
      .mockResolvedValueOnce(
        jsonResponse({ uploads: [presignedUploadFor("verification.pdf", "signed-id-1")] })
      )
      .mockResolvedValueOnce(s3Response(403, "AccessDenied"))

    await selectFiles(buildFile("verification.pdf", "application/pdf", 1024))

    expect(submitButton().disabled).toBe(false)
    expect(errorText()).toBe(FAILED)
  })

  it("hashes one file at a time so a multi-file selection cannot exhaust memory", async () => {
    let concurrent = 0
    let peak = 0
    fileChecksum.mockImplementation(async () => {
      peak = Math.max(peak, (concurrent += 1))
      await Promise.resolve()
      concurrent -= 1
      return CHECKSUM
    })

    fetch
      .mockResolvedValueOnce(
        jsonResponse({
          uploads: [
            presignedUploadFor("a.pdf", "signed-id-1"),
            presignedUploadFor("b.pdf", "signed-id-2"),
            presignedUploadFor("c.pdf", "signed-id-3"),
          ],
        })
      )
      .mockResolvedValue({ ok: true, status: 204 })

    await selectFiles(
      buildFile("a.pdf", "application/pdf", 1024),
      buildFile("b.pdf", "application/pdf", 1024),
      buildFile("c.pdf", "application/pdf", 1024)
    )

    expect(fileChecksum).toHaveBeenCalledTimes(3)
    expect(peak).toBe(1)
  })

  it("sends the browser-computed checksum with the presign request", async () => {
    fetch
      .mockResolvedValueOnce(
        jsonResponse({ uploads: [presignedUploadFor("verification.pdf", "signed-id-1")] })
      )
      .mockResolvedValueOnce({ ok: true, status: 204 })

    await selectFiles(buildFile("verification.pdf", "application/pdf", 1024))

    const payload = JSON.parse(fetch.mock.calls[0][1].body)

    expect(payload.files[0]).toEqual({
      filename: "verification.pdf",
      content_type: "application/pdf",
      byte_size: 1024,
      checksum: CHECKSUM,
    })
  })

  it("rejects an oversized file without contacting the server", async () => {
    await selectFiles(buildFile("huge.pdf", "application/pdf", MAX_FILE_SIZE + 1))

    expect(fetch).not.toHaveBeenCalled()
    expect(errorText()).toBe(TOO_LARGE)
    expect(signedIdValues()).toEqual([])
  })

  it("rejects a disallowed file type without contacting the server", async () => {
    await selectFiles(buildFile("installer.exe", "application/x-msdownload", 1024))

    expect(fetch).not.toHaveBeenCalled()
    expect(errorText()).toBe(UNSUPPORTED)
  })

  it("accepts any image type the allowlist wildcard covers", async () => {
    fetch
      .mockResolvedValueOnce(
        jsonResponse({ uploads: [presignedUploadFor("photo.heic", "signed-id-1")] })
      )
      .mockResolvedValueOnce({ ok: true, status: 204 })

    await selectFiles(buildFile("photo.heic", "image/heic", 1024))

    expect(errorText()).toBe("")
    expect(signedIdValues()).toEqual(["signed-id-1"])
  })

  it("surfaces the server's message when the policy request is refused", async () => {
    fetch.mockResolvedValueOnce(jsonResponse({ error: UNSUPPORTED }, 422))

    await selectFiles(buildFile("installer.pdf", "application/pdf", 1024))

    expect(errorText()).toBe(UNSUPPORTED)
    expect(signedIdValues()).toEqual([])
  })

  it("reports S3's EntityTooLarge as a size problem rather than a generic failure", async () => {
    fetch
      .mockResolvedValueOnce(
        jsonResponse({ uploads: [presignedUploadFor("verification.pdf", "signed-id-1")] })
      )
      .mockResolvedValueOnce(s3Response(400, "EntityTooLarge"))

    await selectFiles(buildFile("verification.pdf", "application/pdf", 1024))

    expect(errorText()).toBe(TOO_LARGE)
    expect(signedIdValues()).toEqual([])
  })

  it("reports other S3 failures generically", async () => {
    fetch
      .mockResolvedValueOnce(
        jsonResponse({ uploads: [presignedUploadFor("verification.pdf", "signed-id-1")] })
      )
      .mockResolvedValueOnce(s3Response(403, "AccessDenied"))

    await selectFiles(buildFile("verification.pdf", "application/pdf", 1024))

    expect(errorText()).toBe(FAILED)
  })

  it("accumulates files across separate selections", async () => {
    fetch
      .mockResolvedValueOnce(
        jsonResponse({ uploads: [presignedUploadFor("first.pdf", "signed-id-1")] })
      )
      .mockResolvedValueOnce({ ok: true, status: 204 })

    await selectFiles(buildFile("first.pdf", "application/pdf", 1024))

    fetch
      .mockResolvedValueOnce(
        jsonResponse({ uploads: [presignedUploadFor("second.pdf", "signed-id-2")] })
      )
      .mockResolvedValueOnce({ ok: true, status: 204 })

    await selectFiles(buildFile("second.pdf", "application/pdf", 1024))

    expect(signedIdValues()).toEqual(["signed-id-1", "signed-id-2"])
    expect(Array.from(listItems()).map((li) => li.textContent.trim())).toEqual([
      expect.stringContaining("first.pdf"),
      expect.stringContaining("second.pdf"),
    ])
    expect(input.value).toBe("")
  })

  it("shows a count that tracks the uploaded files", async () => {
    fetch
      .mockResolvedValueOnce(
        jsonResponse({
          uploads: [
            presignedUploadFor("a.pdf", "signed-id-1"),
            presignedUploadFor("b.pdf", "signed-id-2"),
          ],
        })
      )
      .mockResolvedValue({ ok: true, status: 204 })

    await selectFiles(
      buildFile("a.pdf", "application/pdf", 1024),
      buildFile("b.pdf", "application/pdf", 1024)
    )

    const heading = document.querySelector("[data-document-upload-target=listHeading]")
    const section = document.querySelector("[data-document-upload-target=listSection]")

    expect(section.hidden).toBe(false)
    expect(heading.textContent).toBe("Uploaded documents (2)")
  })

  it("drops the signed ID when an uploaded file is removed", async () => {
    fetch
      .mockResolvedValueOnce(
        jsonResponse({ uploads: [presignedUploadFor("verification.pdf", "signed-id-1")] })
      )
      .mockResolvedValueOnce({ ok: true, status: 204 })

    await selectFiles(buildFile("verification.pdf", "application/pdf", 1024))

    const removeLink = document.querySelector(".document-uploads__remove-link")
    expect(removeLink.classList).toContain("margin-0")
    removeLink.click()

    expect(signedIdValues()).toEqual([])
    expect(listItems()).toHaveLength(0)
    expect(document.querySelector("[data-document-upload-target=listSection]").hidden).toBe(true)
  })
})
