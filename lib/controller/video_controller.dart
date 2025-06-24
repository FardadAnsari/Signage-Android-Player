import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';
import '../model/player_model.dart';
import '../services/dio_service.dart';
import 'package:flutter/material.dart';

class VideoController extends GetxController {
  final DioService dioService = DioService();
  final String apiUrl = 'https://facebook.mega-data.co.uk/player/';

  var videoUrl = ''.obs;
  var isLoading = true.obs;
  var localVideoPath = ''.obs;
  var downloadProgress = 0.0.obs;
  var downloadStatus = ''.obs;
  var isPlaying = false.obs;
  var isInitialized = false.obs;
  var remainingTime = '00:00'.obs;
  var totalDuration = '00:00'.obs;
  var currentPosition = '00:00'.obs;
  var isConnected = true.obs;
  var currentDuration = Duration.zero.obs;
  var currentPositionDuration = Duration.zero.obs;




  VideoPlayerController? videoPlayerController;
  Timer? _timer;
  var isFullScreen = false.obs;

  @override
  void onInit() {
    super.onInit();
    _configureSecuritySettings();
    initVideoPlayer();
  }

  void _configureSecuritySettings() {
    HttpClient client =
        HttpClient()
          ..badCertificateCallback = (
            X509Certificate cert,
            String host,
            int port,
          ) {
            return host == 'facebook.mega-data.co.uk';
          };

    HttpOverrides.global = MyHttpOverrides();
  }
  
  void initVideoPlayer() {
    _checkAndPlayDownloadedVideo();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _silentlyCheckForNewVideo(),
    );
  }

  Future<void> _checkAndPlayDownloadedVideo() async {
    if (localVideoPath.value.isNotEmpty) {
      try {
        final file = File(localVideoPath.value);
        if (await file.exists()) {
          await loadVideo(localVideoPath.value);
          _silentlyCheckForNewVideo();
          return;
        }
      } catch (e) {
        print('Error loading downloaded video: $e');
      }
    }
    fetchVideoUrl();
  }

  Future<void> _silentlyCheckForNewVideo() async {
    try {
      final response = await dioService.getMethod(apiUrl);
      isConnected.value = true;

      if (response.statusCode == 200) {
        PlayerModel playerModel = PlayerModel.fromJson(response.data);
        final newLink = playerModel.link!;

        if (newLink != videoUrl.value) {
          videoUrl.value = newLink;
          await _downloadAndPlayVideo(newLink);
        }
      }
    } catch (e) {
      print('Error checking for new video: $e');
      isConnected.value = false;
      // Continue playing current video if there's an error
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> fetchVideoUrl() async {
    try {
      isLoading.value = true;
      isConnected.value = true;

      final response = await dioService.getMethod(apiUrl);

      if (response.statusCode == 200) {
        PlayerModel playerModel = PlayerModel.fromJson(response.data);
        final newLink = playerModel.link!;

        if (newLink != videoUrl.value) {
          videoUrl.value = newLink;
          await _downloadAndPlayVideo(newLink);
        }
      }
    } catch (e) {
      print('Error fetching video URL: $e');
      isConnected.value = false;
      if (localVideoPath.value.isNotEmpty) {
        try {
          final file = File(localVideoPath.value);
          if (await file.exists()) {
            await loadVideo(localVideoPath.value);
            return;
          }
        } catch (e) {
          print('Error loading downloaded video: $e');
        }
      }

      Get.snackbar(
        "Connection Error",
        "No downloaded video available. Please check your internet connection.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _downloadAndPlayVideo(String url) async {
    try {
      downloadStatus.value = 'downloading...';
      downloadProgress.value = 0.0;
      isConnected.value = true;

      final directory = await getApplicationDocumentsDirectory();
      final videoDir = Directory('${directory.path}/videos');

      if (!await videoDir.exists()) {
        await videoDir.create(recursive: true);
      }

      final filename = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = path.join(videoDir.path, filename);

      await dioService.downloadVideo(
        url: url,
        savePath: filePath,
        onProgress: (received, total) {
          if (total != -1) {
            downloadProgress.value = received / total;
          }
        },
      );

      if (localVideoPath.value.isNotEmpty) {
        final previousFile = File(localVideoPath.value);
        if (await previousFile.exists()) {
          await previousFile.delete();
        }
      }

      localVideoPath.value = filePath;
      downloadStatus.value = 'download completed.';
      await Future.delayed(
        const Duration(seconds: 2),
      ); // Show completion message briefly
      downloadStatus.value = ''; // Clear status after showing completion
      await loadVideo(filePath);
    } catch (e) {
      print('Download error: $e');
      isConnected.value = false;
      try {
        downloadStatus.value = 'playing...';
        await loadVideo(url);
        downloadStatus.value =
            ''; // Clear status after successful online playback
      } catch (e) {
        print('Online playback error: $e');
        downloadStatus.value = 'error playing.';
        await Future.delayed(
          const Duration(seconds: 3),
        ); // Show error message briefly
        downloadStatus.value = ''; // Clear status after showing error

        Get.snackbar(
          "error playing.",
          "error playing. please check your connection.",
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }


  Future<void> loadVideo(String path) async {
    try {
      final oldController = videoPlayerController;

      videoPlayerController =
          path.startsWith('http')
                ? VideoPlayerController.network(path)
                : VideoPlayerController.file(File(path))
            ..setLooping(true)
            ..addListener(_videoListener);

      await videoPlayerController!.initialize();
      isInitialized.value = true;
      currentDuration.value = videoPlayerController!.value.duration;
      currentPositionDuration.value = videoPlayerController!.value.position;

      if (oldController != null) {
        await oldController.dispose();
      }

      await videoPlayerController!.play();
      isPlaying.value = true;
      updateAllVideoPlayers();
    } catch (e) {
      print('Video load error: $e');
      isInitialized.value = false;
      if (localVideoPath.value.isNotEmpty && path != localVideoPath.value) {
        await loadVideo(localVideoPath.value);
      }
    }
  }

  void _videoListener() {
    if (videoPlayerController != null) {
      if (videoPlayerController!.value.hasError) {
        print('Video error: ${videoPlayerController!.value.errorDescription}');
        if (localVideoPath.value.isNotEmpty) {
          loadVideo(localVideoPath.value);
        }
      }

      isPlaying.value = videoPlayerController!.value.isPlaying;
      isInitialized.value = videoPlayerController!.value.isInitialized;

      // Update time information
      final position = videoPlayerController!.value.position;
      final duration = videoPlayerController!.value.duration;

      currentPositionDuration.value = position;
      currentDuration.value = duration;

      currentPosition.value = _formatDuration(position);
      totalDuration.value = _formatDuration(duration);
      remainingTime.value = _formatDuration(duration - position);

      // Check if video is near the end and restart if needed
      if (duration.inSeconds > 0 &&
          position.inSeconds >= duration.inSeconds - 1) {
        videoPlayerController!.seekTo(Duration.zero);
        videoPlayerController!.play();
      }
    }
  }

  void updateAllVideoPlayers() {
    update();
  }

  @override
  void onClose() {
    _timer?.cancel();
    videoPlayerController?.dispose();
    super.onClose();
  }
}

class FullScreenVideoPlayerController {}

// Custom HttpOverrides class with proper security settings
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return host == 'facebook.mega-data.co.uk';
      }
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 5);
  }
}
