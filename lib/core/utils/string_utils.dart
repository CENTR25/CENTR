/// Fold Spanish accents and lowercase, for accent/case-insensitive search.
/// Covers the closed set of Spanish diacritics (á é í ó ú ü ñ).
String foldSearch(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ñ', 'n');
