import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart'; // Tambahan buat thumbnail
import 'package:video_player/video_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SamsungVideoApp());
}

class SamsungVideoApp extends StatelessWidget {
  const SamsungVideoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, 
        colorSchemeSeed: const Color(0xFF0377FF),
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      ),
      home: const VideoHomeScreen(),
    );
  }
}

class VideoHomeScreen extends StatefulWidget {
  const VideoHomeScreen({super.key});
  @override
  State<VideoHomeScreen> createState() => _VideoHomeScreenState();
}

class _VideoHomeScreenState extends State<VideoHomeScreen> {
  List<AssetEntity> videoList = [];
  Set<AssetEntity> selectedVideos = {};
  bool isSelectionMode = false;
  bool _isLoading = true;
  double gridCount = 2.0;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(type: RequestType.video);
    if (paths.isNotEmpty) {
      List<AssetEntity> entities = await paths[0].getAssetListRange(start: 0, end: 100);
      setState(() {
        videoList = entities;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  // Fungsi pengganti durationString yang hilang
  String _printDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0377FF),
        elevation: 0,
        title: Text(isSelectionMode ? "${selectedVideos.length} Terpilih" : "Re Video Library", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: isSelectionMode ? IconButton(icon: const Icon(Icons.close, color: Colors.white), 
          onPressed: () => setState(() { isSelectionMode = false; selectedVideos.clear(); })) : null,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onScaleUpdate: (details) {
                setState(() {
                  if (details.scale > 1.2) gridCount = 2.0;
                  if (details.scale < 0.8) gridCount = 3.0;
                });
              },
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridCount.toInt(), 
                  mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.8),
                itemCount: videoList.length,
                itemBuilder: (context, index) {
                  final video = videoList[index];
                  final isSelected = selectedVideos.contains(video);

                  return GestureDetector(
                    onLongPress: () {
                      setState(() { isSelectionMode = true; selectedVideos.add(video); });
                    },
                    onTap: () {
                      if (isSelectionMode) {
                        setState(() { 
                          isSelected ? selectedVideos.remove(video) : selectedVideos.add(video); 
                          if (selectedVideos.isEmpty) isSelectionMode = false;
                        });
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => SamsungPlayerScreen(video: video)));
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  width: double.infinity,
                                  color: Colors.black12,
                                  // PERBAIKAN: Pakai AssetEntityImage dari provider
                                  child: AssetEntityImage(
                                    video,
                                    isOriginal: false,
                                    thumbnailSize: const ThumbnailSize(400, 400),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              if (isSelectionMode) Positioned(
                                top: 8, left: 8,
                                child: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: Colors.blue, size: 28),
                              ),
                              Positioned(bottom: 8, right: 8, child: Container(
                                padding: const EdgeInsets.all(4), 
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                // PERBAIKAN: Pakai fungsi manual _printDuration
                                child: Text(_printDuration(video.videoDuration), style: const TextStyle(color: Colors.white, fontSize: 10)),
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(video.title ?? "Video", maxLines: 1, overflow: TextOverflow.ellipsis, 
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ),
      bottomNavigationBar: isSelectionMode ? BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(icon: const Icon(Icons.share), onPressed: () async {
              List<XFile> files = [];
              for (var v in selectedVideos) { 
                final f = await v.file; 
                if(f != null) files.add(XFile(f.path)); 
              }
              if (files.isNotEmpty) await Share.shareXFiles(files);
            }),
          ],
        ),
      ) : null,
    );
  }
}

class SamsungPlayerScreen extends StatefulWidget {
  final AssetEntity video;
  const SamsungPlayerScreen({super.key, required this.video});
  @override
  State<SamsungPlayerScreen> createState() => _SamsungPlayerScreenState();
}

class _SamsungPlayerScreenState extends State<SamsungPlayerScreen> {
  VideoPlayerController? _controller;
  double _volume = 0.5;
  double _brightness = 0.5;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final file = await widget.video.file;
    if (file != null) {
      _controller = VideoPlayerController.file(file)..initialize().then((_) {
        setState(() { _controller!.play(); });
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller != null && _controller!.value.isInitialized
          ? GestureDetector(
              onVerticalDragUpdate: (details) async {
                double height = MediaQuery.of(context).size.height;
                if (details.globalPosition.dx > MediaQuery.of(context).size.width / 2) {
                  _volume = (_volume - details.delta.dy / height).clamp(0.0, 1.0);
                  _controller!.setVolume(_volume);
                } else {
                  _brightness = (_brightness - details.delta.dy / height).clamp(0.0, 1.0);
                  await ScreenBrightness().setScreenBrightness(_brightness);
                }
                setState(() {});
              },
              onDoubleTap: () => _controller!.value.isPlaying ? _controller!.pause() : _controller!.play(),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                  Positioned(
                    bottom: 20, left: 20, right: 20,
                    child: VideoProgressIndicator(_controller!, allowScrubbing: true, 
                      colors: const VideoProgressColors(playedColor: Color(0xFF0377FF))),
                  ),
                  Positioned(
                    top: 40, left: 20,
                    child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), 
                      onPressed: () => Navigator.pop(context)),
                  )
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
