import { Controller } from "@hotwired/stimulus"
import CSRF from "../utilities/csrf"
import fileChecksum from "../utilities/file_checksum"

export default class extends Controller {
  static targets = ["input", "list", "listHeading", "error", "signedIds"]

  static values = {
    presignUrl: String,
    maxFileSize: Number,
    allowedTypes: String,
    headingTemplate: String,
    removeLabel: String,
    iconHref: String,
    errorTooLarge: String,
    errorUnsupportedType: String,
    errorUploadFailed: String,
  }

  connect() {
    this.clearing = false
  }

  async select() {
    if (this.clearing) return

    const files = Array.from(this.inputTarget.files)
    if (files.length === 0) return

    for (const file of files) {
      const message = this.#validate(file)
      if (message) {
        this.#showError(message)
        this.#clearInput()
        return
      }
    }

    this.#showError(null)

    try {
      const uploads = await this.#requestPresignedUploads(files)

      await Promise.all(uploads.map((upload, index) => this.#upload(files[index], upload)))

      uploads.forEach((upload) => this.#record(upload))
      this.#refreshList()
    } catch (error) {
      this.#showError(error.message || this.errorUploadFailedValue)
    } finally {
      this.#clearInput()
    }
  }

  remove(event) {
    event.preventDefault()

    const item = event.target.closest("[data-signed-id]")
    const signedId = item.dataset.signedId

    Array.from(this.signedIdsTarget.children)
      .filter((input) => input.value === signedId)
      .forEach((input) => input.remove())

    item.remove()
    this.#refreshList()
  }

  #validate(file) {
    if (file.size > this.maxFileSizeValue) return this.errorTooLargeValue

    const allowed = this.allowedTypesValue.split(",").some((pattern) => {
      const type = pattern.trim()
      return type.endsWith("/*") ? file.type.startsWith(type.slice(0, -1)) : file.type === type
    })

    return allowed ? null : this.errorUnsupportedTypeValue
  }

  async #requestPresignedUploads(files) {
    const checksums = []
    for (const file of files) {
      checksums.push(await fileChecksum(file))
    }

    const response = await fetch(this.presignUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": CSRF.token,
      },
      body: JSON.stringify({
        files: files.map((file, index) => ({
          filename: file.name,
          content_type: file.type,
          byte_size: file.size,
          checksum: checksums[index],
        })),
      }),
    })

    const body = await this.#json(response)

    if (!response.ok || !body?.uploads) {
      throw new Error(body?.error || this.errorUploadFailedValue)
    }

    return body.uploads
  }

  async #upload(file, upload) {
    const form = new FormData()
    Object.entries(upload.fields).forEach(([name, value]) => form.append(name, value))
    form.append("file", file)

    const response = await fetch(upload.url, { method: "POST", body: form })

    if (!response.ok) {
      const code = await this.#s3ErrorCode(response)

      throw new Error(
        code === "EntityTooLarge" ? this.errorTooLargeValue : this.errorUploadFailedValue
      )
    }
  }

  async #s3ErrorCode(response) {
    try {
      const xml = new DOMParser().parseFromString(await response.text(), "text/xml")
      return xml.querySelector("Code")?.textContent
    } catch {
      return null
    }
  }

  #record(upload) {
    const field = document.createElement("input")
    field.type = "hidden"
    field.name = "activity[document_uploads][]"
    field.value = upload.signed_id
    this.signedIdsTarget.appendChild(field)

    this.listTarget.appendChild(this.#buildItem(upload))
  }

  #buildItem(upload) {
    const item = document.createElement("li")
    item.className = "document-uploads__item"
    item.dataset.signedId = upload.signed_id

    const file = document.createElement("div")
    file.className = "document-uploads__file"

    const icon = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    icon.setAttribute("class", "usa-icon document-uploads__icon")
    icon.setAttribute("aria-hidden", "true")
    icon.setAttribute("focusable", "false")
    icon.setAttribute("role", "img")

    const use = document.createElementNS("http://www.w3.org/2000/svg", "use")
    use.setAttribute("href", this.iconHrefValue)
    icon.appendChild(use)

    const filename = document.createElement("span")
    filename.className = "document-uploads__filename"
    filename.textContent = upload.filename

    file.append(icon, filename)

    const remove = document.createElement("button")
    remove.type = "button"
    remove.className = "usa-button usa-button--unstyled document-uploads__remove-link"
    remove.dataset.action = "document-upload#remove"
    remove.textContent = this.removeLabelValue

    item.append(file, remove)

    return item
  }

  #refreshList() {
    const count = this.listTarget.children.length

    this.listTarget.hidden = count === 0
    this.listHeadingTarget.hidden = count === 0
    this.listHeadingTarget.textContent = this.headingTemplateValue.replace("%{count}", count)
  }

  async #json(response) {
    try {
      return await response.json()
    } catch {
      return null
    }
  }

  #showError(message) {
    this.errorTarget.textContent = message || ""
    this.errorTarget.hidden = !message
  }

  #clearInput() {
    this.clearing = true
    this.inputTarget.value = ""
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.clearing = false
  }
}
