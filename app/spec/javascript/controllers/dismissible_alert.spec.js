import { describe, beforeEach, afterEach, it, expect, vi } from "vitest"
import { JSDOM } from "jsdom"
import DismissibleAlertController from "@js/controllers/dismissible_alert_controller"

describe("DismissibleAlertController", () => {
  const storage = new JSDOM("", { url: "https://example.test" }).window.sessionStorage

  const renderAlert = async (key = "unpaid-work-1") => {
    document.body.innerHTML = `
      <div data-controller="dismissible-alert" data-dismissible-alert-key-value="${key}">
        Helpful guidance
        <button type="button" data-action="dismissible-alert#dismiss">Dismiss</button>
      </div>
    `
    const alert = document.querySelector('[data-controller="dismissible-alert"]')
    await vi.waitFor(() => {
      expect(
        window.Stimulus.getControllerForElementAndIdentifier(alert, "dismissible-alert")
      ).toBeTruthy()
    })
    return alert
  }

  beforeEach(() => {
    storage.clear()
    vi.spyOn(window, "sessionStorage", "get").mockReturnValue(storage)
    window.Stimulus.register("dismissible-alert", DismissibleAlertController)
  })

  afterEach(() => {
    vi.restoreAllMocks()
    document.body.innerHTML = ""
    storage.clear()
  })

  it("shows guidance until dismissed", async () => {
    const alert = await renderAlert()
    expect(alert.hidden).toBe(false)

    alert.querySelector("button").click()

    expect(alert.hidden).toBe(true)
  })

  it("keeps a dismissed alert hidden when it is rendered again", async () => {
    const alert = await renderAlert()
    alert.querySelector("button").click()

    expect((await renderAlert()).hidden).toBe(true)
  })

  it("does not dismiss alerts with different keys", async () => {
    const alert = await renderAlert()
    alert.querySelector("button").click()

    expect((await renderAlert("unpaid-work-2")).hidden).toBe(false)
  })

  it("shows the alert again in a fresh browser session", async () => {
    const alert = await renderAlert()
    alert.querySelector("button").click()
    window.sessionStorage.clear()

    expect((await renderAlert()).hidden).toBe(false)
  })

  it("leaves alerts without a key visible without accessing storage", async () => {
    const getItem = vi.spyOn(storage, "getItem")
    const alert = await renderAlert("")

    expect(alert.hidden).toBe(false)
    expect(getItem).not.toHaveBeenCalled()
  })

  it("allows dismissal when browser storage is unavailable", async () => {
    vi.spyOn(window, "sessionStorage", "get").mockImplementation(() => {
      throw new DOMException("Storage blocked", "SecurityError")
    })
    const alert = await renderAlert()

    expect(alert.hidden).toBe(false)
    alert.querySelector("button").click()
    expect(alert.hidden).toBe(true)
  })
})
