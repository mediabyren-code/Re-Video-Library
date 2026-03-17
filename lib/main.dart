import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
        scaffoldBackgroundColor: Colors.white,
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

class _VideoHomeScreenState extends State<VideoHomeScreen> with WidgetsBindingObserver {
  List<AssetEntity> videoList = [];
  Set<AssetEntity> selectedVideos = {};
  bool isSelectionMode = false;
  bool _isLoading = true;
  double gridCount = 3.0; 
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchVideos();
    }
  }

  // FIX PERMISSION: Menggunakan requestPermissionExtend() yang benar
  Future<void> _checkPermission() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth || ps.hasAccess) {
      _fetchVideos();
      PhotoManager.addChangeCallback((_) => _fetchVideos());
      PhotoManager.startChangeNotify();
    } else {
      // Jika ditolak, arahkan ke setting agar otomatis aktif kedepannya
      PhotoManager.openSetting();
    }
  }

  Future<void> _fetchVideos() async {
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(type: RequestType.video);
    if (paths.isNotEmpty) {
      final List<AssetEntity> entities = await paths[0].getAssetListRange(start: 0, end: 500);
      if (mounted) {
        setState(() {
          videoList = entities;
          _isLoading = false;
        });
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredVideos = videoList.where((v) => (v.title ?? "").toLowerCase().contains(searchQuery.toLowerCase())).toList();

    return Scaffold(
      appBar: isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!isSelectionMode) _buildSearchBar(),
                Expanded(
                  child: GestureDetector(
                    onScaleUpdate: (details) {
                      setState(() {
                        if (details.scale > 1.1) gridCount = 2.0; 
                        if (details.scale < 0.9) gridCount = 4.0; 
                      });
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.all(4),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridCount.toInt(),
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        childAspectRatio: 1,
                      ),
                      itemCount: filteredVideos.length,
                      itemBuilder: (context, index) {
                        final video = filteredVideos[index];
                        final isSelected = selectedVideos.contains(video);

                        return GestureDetector(
                          onLongPress: () {
                            HapticFeedback.selectionClick();
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
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: AssetThumbnail(asset: video),
                                ),
                                if (isSelectionMode) Positioned(top: 5, left: 5, child: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: Colors.blue, size: 24)),
                                Positioned(bottom: 5, right: 5, child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                  child: Text(_formatDuration(video.videoDuration), style: const TextStyle(color: Colors.white, fontSize: 10)))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: isSelectionMode ? _buildBottomActions() : null,
    );
  }

  AppBar _buildNormalAppBar() => AppBar(
    title: const Text("Video", style: TextStyle(fontWeight: FontWeight.bold)),
  );

  AppBar _buildSelectionAppBar() => AppBar(
    leading: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { isSelectionMode = false; selectedVideos.clear(); })),
    title: Text("${selectedVideos.length} Terpilih"),
  );

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: TextField(
      onChanged: (val) => setState(() => searchQuery = val),
      decoration: InputDecoration(
        hintText: "Cari video...",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        contentPadding: EdgeInsets.zero,
      ),
    ),
  );

  Widget _buildBottomActions() => BottomAppBar(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _actionItem(Icons.share, "Berbagi", () async {
          List<XFile> files = [];
          for (var v in selectedVideos) { final f = await v.file; if(f != null) files.add(XFile(f.path)); }
          Share.shareXFiles(files);
        }),
        if (selectedVideos.length == 1) _actionItem(Icons.edit, "Ubah Nama", () {}),
        _actionItem(Icons.delete, "Hapus", () {}),
        _actionItem(Icons.folder_copy, "Pindahkan", () {}),
      ],
    ),
  );

  Widget _actionItem(IconData icon, String label, VoidCallback tap) => InkWell(onTap: tap, child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon), Text(label, style: const TextStyle(fontSize: 10))]));

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, "0");
    return d.inHours > 0 ? "${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}" : "${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}";
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
  bool _showControls = true;
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
        _hideControlsLater();
      });
    }
  }

  void _hideControlsLater() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
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
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Center(child: AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: VideoPlayer(_controller!))),
                
                // GESTURE LAYER (Volume, Brightness, Seek)
                GestureDetector(
                  onTap: () => setState(() => _showControls = !_showControls),
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
                  onDoubleTap: () {
                    _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                    setState(() {});
                  },
                ),

                if (_showControls) ...[
                  _buildTopBar(),
                  _buildCenterIcon(),
                  _buildBottomUI(),
                ],
              ],
            ),
    );
  }

  Widget _buildTopBar() => Positioned(
    top: 40, left: 10, right: 10,
    child: Row(
      children: [
        IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        Expanded(child: Text(widget.video.title ?? "Video", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
      ],
    ),
  );

  Widget _buildCenterIcon() => Center(
    child: Icon(_controller!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white60, size: 70),
  );

  Widget _buildBottomUI() => Positioned(
    bottom: 40, left: 20, right: 20,
    child: Column(
      children: [
        VideoProgressIndicator(_controller!, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Color(0xFF0377FF))),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(_controller!.value.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
            Row(children: [
              IconButton(icon: const Icon(Icons.screen_rotation, color: Colors.white), onPressed: () {
                SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.portraitUp]);
              }),
            ]),
            Text(_formatDuration(_controller!.value.duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ],
    ),
  );

  String _formatDuration(Duration d) => "${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(d.inSeconds.remainder(60)).toString().padLeft(2, '0')}";
}

class AssetThumbnail extends StatelessWidget {
  final AssetEntity asset;
  const AssetThumbnail({super.key, required this.asset});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailData,
      builder: (_, snap) => snap.hasData ? Image.memory(snap.data!, fit: BoxFit.cover) : Container(color: Colors.black12),
    );
  }
}
