type Status = "succeeded" | "failed"

const getIndicatorElements = () => document.getElementsByClassName("synchronizations-indicator")

const removeInProgressStyles = (svg: SVGSVGElement, use: SVGUseElement, span: HTMLSpanElement) => {
  svg.classList.remove("rotate", "border-base-light")
  span.classList.remove("text-thin")

  const href = use.getAttribute("xlink:href")
  if (href) {
    use.setAttribute("xlink:href", href.split("#")[0])
  }
}

const addSucceededStyles = (svg: SVGSVGElement, use: SVGUseElement, span: HTMLSpanElement) => {
  svg.classList.add("text-white", "bg-primary", "border-primary")
  span.classList.add("text-bold", "text-primary")

  const href = use.getAttribute("xlink:href")
  if (href) {
    use.setAttribute("xlink:href", `${href}#check`)
  }
}

const addFailedStyles = (svg: SVGSVGElement, use: SVGUseElement, span: HTMLSpanElement) => {
  svg.classList.add("text-white", "bg-base-darker", "border-base-darker")
  span.classList.add("text-bold")

  const href = use.getAttribute("xlink:href")
  if (href) {
    use.setAttribute("xlink:href", `${href}#priority_hight`)
  }
}

const handleStatusUpdate =
  (svg: SVGSVGElement, use: SVGUseElement, span: HTMLSpanElement) => (status: Status) => {
    removeInProgressStyles(svg, use, span)

    if (status === "succeeded") {
      addSucceededStyles(svg, use, span)
    } else {
      addFailedStyles(svg, use, span)
    }
  }

const elementToHandler = (element: HTMLElement) => {
  const svg = element.getElementsByTagName("svg").item(0)
  if (!svg) {
    return null
  }

  const use = element.getElementsByTagName("use").item(0)
  if (!use) {
    return null
  }

  const span = element.getElementsByTagName("span").item(0)
  if (!span) {
    return null
  }

  return handleStatusUpdate(svg, use, span)
}

const setupListeners = (stream: EventSource, elements: HTMLCollection) => {
  for (let idx = 0; idx < elements.length; idx++) {
    const el = elements.item(idx)
    if (!el || !(el instanceof HTMLElement)) {
      continue
    }

    const name = el?.getAttribute("name")
    if (!name) {
      continue
    }

    const handler = elementToHandler(el)
    if (!handler) {
      continue
    }

    stream.addEventListener(
      name,
      (e) => {
        handler(e.data)
      },
      { once: true }
    )
  }
}

document.addEventListener("DOMContentLoaded", () => {
  const container = document.getElementById("education-index-container")
  if (!container) {
    console.error("Failed to find container")
    return
  }

  const eventSourceUrl = container.dataset["eventSourceUrl"]
  if (!eventSourceUrl) {
    console.error("Failed to find event source url")
    return
  }

  const indicators = getIndicatorElements()
  const stream = new EventSource(eventSourceUrl)
  setupListeners(stream, indicators)
})
