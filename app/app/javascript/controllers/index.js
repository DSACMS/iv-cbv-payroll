// This file is auto-generated by ./bin/rails stimulus:manifest:update
// Run that command whenever you add a new controller or create them with
// ./bin/rails generate stimulus controllerName

import { application } from "./application"

import CbvEmployerSearch from "./cbv/employer_search"
import CbvSynchronizationsController from "./cbv/synchronizations_controller"
import CbvSessionsTimeoutController from "./cbv/sessions_controller.js"
import HelpController from "./help"

application.register("cbv-employer-search", CbvEmployerSearch)
application.register("cbv-synchronizations", CbvSynchronizationsController)
application.register("session", CbvSessionsTimeoutController)
application.register("help", HelpController)
