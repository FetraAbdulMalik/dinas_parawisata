const _destinationImageAliases = {
  'kawah_talaga_bodas': 'assets/images/talaga_bodas.jpg',
  'situ_bagendit': 'assets/images/situ_bangendit.jpg',
};

String destinationImageSlug(String destinationName) => destinationName
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

String? findDestinationImageAsset(
  String destinationName,
  Set<String> availableAssets, {
  String fallbackAsset = '',
}) {
  final slug = destinationImageSlug(destinationName);
  final alias = _destinationImageAliases[slug];
  if (alias != null && availableAssets.contains(alias)) return alias;

  for (final asset in availableAssets) {
    if (!asset.startsWith('assets/images/')) continue;
    final fileName = asset.split('/').last;
    final extensionIndex = fileName.lastIndexOf('.');
    final nameWithoutExtension = extensionIndex == -1
        ? fileName
        : fileName.substring(0, extensionIndex);
    if (destinationImageSlug(nameWithoutExtension) == slug) return asset;
  }

  if (fallbackAsset.startsWith('assets/images/') &&
      availableAssets.contains(fallbackAsset)) {
    return fallbackAsset;
  }
  return null;
}
