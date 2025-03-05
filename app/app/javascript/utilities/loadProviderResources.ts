import loadScript from "load-script"

export const loadArgyleResource = async () => {
  return await new Promise((resolve, reject) => {
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
