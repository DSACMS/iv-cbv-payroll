// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"

import "@uswds/uswds"

// make sure USWDS components are wired to their behavior after a Turbo navigation
import components from "@uswds/uswds/src/js/components"

// Loops through USWDS components and reinitializes them on the page
// Each behavior handles the JavaScript functionality for a UI component
// See: https://github.com/uswds/uswds/blob/852076b6409e20ba95e3a589ad3cf38ca9b68442/packages/uswds-core/src/js/start.js
document.addEventListener("turbo:render", () => {
  const target = document.body
  Object.keys(components).forEach((key) => {
    const behavior = components[key]
    behavior.on(target)
  })
})
