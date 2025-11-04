import { application } from "./application"

import CbvEmployerSearch from "./cbv/employer_search"
import CbvSessionsTimeoutController from "./cbv/sessions_controller.js"
import HelpController from "./help"
import PollingController from "./polling_controller.js"
import LanguageController from "./language_controller.js"
import CopyLinkController from "./copy_link_controller.js"
import CbvEntryPageController from "./cbv/entry_page_controller.js"
import PreviewFormController from "./preview_form_controller.js"

application.register("cbv-employer-search", CbvEmployerSearch)
application.register("polling", PollingController)
application.register("session", CbvSessionsTimeoutController)
application.register("help", HelpController)
application.register("language", LanguageController)
application.register("copy-link", CopyLinkController)
application.register("cbv-entry-page", CbvEntryPageController)
application.register("preview-form", PreviewFormController)

Turbo.StreamActions.redirect = function () {
  Turbo.visit(this.target)
}
