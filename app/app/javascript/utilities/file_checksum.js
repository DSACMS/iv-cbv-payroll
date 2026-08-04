import SparkMD5 from "spark-md5"

const CHUNK_SIZE = 2 * 1024 * 1024

export default function fileChecksum(file) {
  return new Promise((resolve, reject) => {
    const md5 = new SparkMD5.ArrayBuffer()
    const reader = new FileReader()
    let offset = 0

    const readNextChunk = () => {
      if (offset >= file.size) {
        resolve(btoa(md5.end(true)))
        return
      }

      const end = Math.min(offset + CHUNK_SIZE, file.size)
      reader.readAsArrayBuffer(file.slice(offset, end))
      offset = end
    }

    reader.onload = (event) => {
      md5.append(event.target.result)
      readNextChunk()
    }

    reader.onerror = () => reject(reader.error)

    readNextChunk()
  })
}
