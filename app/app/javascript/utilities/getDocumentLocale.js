export const getDocumentLocale = () => {
  const docLocale = document.documentElement.lang;
  if (docLocale) return docLocale;
  // Extract locale from URL path (e.g., /en/cbv/employer_search)
  const pathMatch = window.location.pathname.match(/^\/([a-z]{2})\//i);
  return pathMatch ? pathMatch[1] : 'en';
};
