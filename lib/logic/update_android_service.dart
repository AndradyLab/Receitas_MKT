import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'package:receitas_mkt/data/update_info.dart';

class UpdatePermissionDeniedException implements Exception {
  final String message;
  UpdatePermissionDeniedException(this.message);
  @override
  String toString() => message;
}

class UpdateService {
  static const _repoApiUrl =
      'https://api.github.com/repos/AndradyLab/Receitas_MKT/releases/latest';

  final Dio _dio = Dio();

  Future<UpdateInfo?> checkForUpdate() async {
    final response = await _dio.get(_repoApiUrl);
    final remote = UpdateInfo.fromGithubRelease(response.data);

    final packageInfo = await PackageInfo.fromPlatform();
    final localVersionCode = int.parse(packageInfo.buildNumber);

    if (remote.versionCode > localVersionCode) {
      return remote;
    }
    return null;
  }

  Future<void> downloadAndInstall(
    UpdateInfo update, {
    required void Function(double progress) onProgress,
  }) async {
    final status = await Permission.requestInstallPackages.status;
    if (!status.isGranted) {
      final result = await Permission.requestInstallPackages.request();
      if (!result.isGranted) {
        throw UpdatePermissionDeniedException(
          'Permissão de instalação negada pelo usuário',
        );
      }
    }

    final dirs = await getExternalCacheDirectories();
    final targetDir =
        (dirs != null && dirs.isNotEmpty) ? dirs.first : await getTemporaryDirectory();
    final filePath = '${targetDir.path}/receitas_mkt_update.apk';

    await _dio.download(
      update.downloadUrl,
      filePath,
      onReceiveProgress: (received, total) {
        if (total != -1) onProgress(received / total);
      },
    );

    await OpenFilex.open(filePath);
  }
}