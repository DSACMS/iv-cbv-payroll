import { application } from "./application"

import CbvEmployerSearch from "./cbv/employer_search"
import SessionTimeoutPageController from "./cbv/sessions_timeout_controller.js"
import SessionTimeoutModalController from "./cbv/sessions_controller.js"
import HelpController from "./help"
import PollingController from "./polling_controller.js"
import LanguageController from "./language_controller.js"
import CopyLinkController from "./copy_link_controller.js"
import CommonQuestionsController from "./common_questions_controller.js"
import CbvEntryPageController from "./cbv/entry_page_controller.js"

application.register("cbv-employer-search", CbvEmployerSearch)
application.register("polling", PollingController)
application.register("session", SessionTimeoutModalController)
application.register("help", HelpController)
application.register("language", LanguageController)
application.register("copy-link", CopyLinkController)
application.register("cbv-entry-page", CbvEntryPageController)
application.register("common-questions", CommonQuestionsController)
application.register("session-timeout", SessionTimeoutPageController)

Turbo.StreamActions.redirect = function () {
  Turbo.visit(this.target)
}
