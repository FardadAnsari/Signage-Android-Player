import 'package:dio/dio.dart';

class DioService {
  final Dio _dio = Dio();

  Future<Response> getMethod(String url) async {
    try {
      return await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.json,
          headers: {'Content-Type': 'application/json'},
        ),
      );
    } on DioException catch (e) {
      throw Exception('GET request failed: ${e.message}');
    }
  }

  Future<void> downloadVideo({
    required String url,
    required String savePath,
    required void Function(int received, int total) onProgress,
  }) async {
    try {
      await _dio.download(
        url,
        savePath,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 5),
        ),
        onReceiveProgress: onProgress,
      );
      print('Video downloaded successfully to: $savePath');
    } on DioException catch (e) {
      print('Download error: ${e.message}');
      throw Exception('Video download failed: ${e.message}');
    }
  }
}