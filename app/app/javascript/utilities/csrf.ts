// Borrowed from https://github.com/18F/identity-idp/blob/59bc8bb6c47402f386d9248bfad3c0803f68187e/app/javascript/packages/request/index.ts#L25-L59
export default class CSRF {
  static get token(): string | null {
    return this.#tokenMetaElement?.content || null
  }

  static set token(value: string | null) {
    if (!value) {
      return
    }

    if (this.#tokenMetaElement) {
      this.#tokenMetaElement.content = value
    }

    this.#paramInputElements.forEach((input) => {
      input.value = value
    })
  }

  static get param(): string | undefined {
    return this.#paramMetaElement?.content
  }

  static get #tokenMetaElement(): HTMLMetaElement | null {
    return document.querySelector('meta[name="csrf-token"]')
  }

  static get #paramMetaElement(): HTMLMetaElement | null {
    return document.querySelector('meta[name="csrf-param"]')
  }

  static get #paramInputElements(): NodeListOf<HTMLInputElement> {
    return document.querySelectorAll(`input[name="${this.param}"]`)
  }
}
