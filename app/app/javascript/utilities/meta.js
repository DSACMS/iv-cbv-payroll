function metaContent(name) {
  const element = document.head.querySelector(`meta[name="${name}"]`)
  return element && element.content
}

export default metaContent
