import { Controller } from '@hotwired/stimulus'
import { trackUserAction } from '../utilities/help'

export default class extends Controller {
                  static targets = ['iframe']

                  connect() {
              this.handleClick = (event) => {
                if (event.target.href?.includes('#help-modal')) {
                  trackUserAction('ApplicantOpenedHelpModal', event.target.dataset.source)
                }
                  }

        document.addEventListener('click', this.handleClick)
  }

              disconnect() {
    document.removeEventListener('click', this.handleClick)
  }

  /**
   * This function is used to prepare the next URL for the iframe.
   * It generates a new random parameter and updates the iframe src
   * so that when the modal is opened, the iframe will load the
   * default help topics rather than the last viewed topic.
   */
  prepareNextUrl() {
    const iframe = this.iframeTarget
    const currentSrc = new URL(iframe.src)

    // Generate a new random parameter
    const randomHex = Array.from(crypto.getRandomValues(new Uint8Array(2)))
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('')

    // Update the iframe src with new random parameter
    currentSrc.searchParams.set('r', randomHex)
    iframe.src = currentSrc.toString()
  }
}
