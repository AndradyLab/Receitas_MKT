class UpdateInfo {
  final String version;
  final int versionCode;
  final String downloadUrl;
  final String releaseNotes;

  UpdateInfo({
    required this.version,
    required this.versionCode,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  factory UpdateInfo.fromGithubRelease(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String;
    final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;

    final assets = json['assets'] as List;
    final asset = assets.firstWhere(
      (a) => (a['name'] as String).endsWith('.apk'),
      orElse: () => throw Exception('APK não encontrado nos assets da release'),
    );

    return UpdateInfo(
      version: version,
      versionCode: _versionCodeFromServer(version),
      downloadUrl: asset['browser_download_url'] as String,
      releaseNotes: (json['body'] as String?) ?? '',
    );
  }

  static int _versionCodeFromServer(String v) {
    final parts = v.split('.').map(int.parse).toList();
    return parts[0] * 10000 + parts[1] * 100 + parts[2];
  }
}