import { application } from "./application"

import CbvEmployerSearch from "./cbv/employer_search"
import CbvSessionsTimeoutController from "./cbv/sessions_controller.js"
import HelpController from "./help"
import PollingController from "./polling_controller.js"

application.register("cbv-employer-search", CbvEmployerSearch)
application.register("polling", PollingController)
application.register("session", CbvSessionsTimeoutController)
application.register("help", HelpController)

Turbo.StreamActions.redirect = function () {
  Turbo.visit(this.target)
}
