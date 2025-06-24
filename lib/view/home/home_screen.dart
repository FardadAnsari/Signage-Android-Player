import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:player/controller/video_controller.dart';
import 'dart:async';
import 'package:flutter/services.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VideoController videoController = Get.put(VideoController());
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    videoController.fetchVideoUrl();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });
    _startHideTimer();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _showControlsTemporarily,
        child: Stack(
          children: [
            // Video Player
            Center(
              child: AspectRatio(
                aspectRatio:
                    _isFullScreen
                        ? MediaQuery.of(context).size.aspectRatio
                        : 16 / 9,
                child: Obx(() {
                  if (videoController.isInitialized.value) {
                    return VideoPlayer(videoController.videoPlayerController!);
                  } else {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.red,
                        strokeWidth: 6,
                      ),
                    );
                  }
                }),
              ),
            ),

            // Download Progress (shown first)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Obx(() {
                if (videoController.downloadStatus.value.isNotEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          videoController.downloadStatus.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: videoController.downloadProgress.value,
                          backgroundColor: Colors.grey.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.red,
                          ),
                          minHeight: 8,
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }),
            ),

            // Playback Controls (shown after download)
            if (_showControls && videoController.downloadStatus.value.isEmpty)
              Positioned(
                bottom: 120,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Play/Pause Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            videoController.isPlaying.value
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 48,
                          ),
                          onPressed: () {
                            if (videoController.isPlaying.value) {
                              videoController.videoPlayerController?.pause();
                            } else {
                              videoController.videoPlayerController?.play();
                            }
                            _showControlsTemporarily();
                          },
                          iconSize: 48,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                      // Full Screen Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isFullScreen
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen,
                            color: Colors.white,
                            size: 48,
                          ),
                          onPressed: _toggleFullScreen,
                          iconSize: 48,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Video Progress Bar (shown after download)
            if (_showControls && videoController.downloadStatus.value.isEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Video Progress
                      Obx(() {
                        final duration = videoController.currentDuration.value;
                        final position =
                            videoController.currentPositionDuration.value;
                        final progress =
                            duration.inMilliseconds > 0
                                ? position.inMilliseconds /
                                    duration.inMilliseconds
                                : 0.0;

                        String formatDuration(Duration duration) {
                          String twoDigits(int n) =>
                              n.toString().padLeft(2, '0');
                          final hours = twoDigits(duration.inHours);
                          final minutes = twoDigits(
                            duration.inMinutes.remainder(60),
                          );
                          final seconds = twoDigits(
                            duration.inSeconds.remainder(60),
                          );
                          return hours == '00'
                              ? '$minutes:$seconds'
                              : '$hours:$minutes:$seconds';
                        }

                        final remainingTime = duration - position;
                        final formattedPosition = formatDuration(position);
                        final formattedRemaining = formatDuration(
                          remainingTime,
                        );
                        final formattedDuration = formatDuration(duration);

                        return Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  formattedPosition,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '-$formattedRemaining / $formattedDuration',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 8,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 12,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 24,
                                ),
                                activeTrackColor: Colors.red,
                                inactiveTrackColor: Colors.grey.withOpacity(
                                  0.3,
                                ),
                                thumbColor: Colors.red,
                                overlayColor: Colors.red.withOpacity(0.2),
                              ),
                              child: Slider(
                                value: progress.clamp(0.0, 1.0),
                                onChanged: (value) {
                                  if (videoController.videoPlayerController !=
                                      null) {
                                    final newPosition = Duration(
                                      milliseconds:
                                          (value * duration.inMilliseconds)
                                              .round(),
                                    );
                                    videoController.videoPlayerController!
                                        .seekTo(newPosition);
                                    _showControlsTemporarily();
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
