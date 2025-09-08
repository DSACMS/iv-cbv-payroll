import loadScript from "load-script"

export const loadArgyleResource = async () => {
  return await new Promise((resolve, reject) => {
    // Note: When upgrading this version, make sure to test that the modal
    // works and there are no Content Security Policy errors related to the
    // updated styling. See: config/initializers/content_security_policy.rb.
    loadScript("https://plugin.argyle.com/argyle.web.v5.js", (err, script) => {
      if (err) {
        reject(err)
      } else {
        resolve(Argyle)
      }
    })
  })
}

export const loadPinwheelResource = async () => {
  return await new Promise((resolve, reject) => {
    // Note: When upgrading this version, make sure to test that the modal
    // works and there are no Content Security Policy errors related to the
    // updated styling. See: config/initializers/content_security_policy.rb.
    loadScript("https://cdn.getpinwheel.com/pinwheel-v3.0.js", (err, script) => {
      if (err) {
        reject(err)
      } else {
        resolve(Pinwheel)
      }
    })
  })
}

export const loadProviderResources = async () => {
  await loadArgyleResource()
  await loadPinwheelResource()
}
