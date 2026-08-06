export default async function fileChecksum(file) {
  const digest = await crypto.subtle.digest("SHA-256", await file.arrayBuffer())

  return btoa(String.fromCharCode(...new Uint8Array(digest)))
}
