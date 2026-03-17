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
  // Kunci orientasi ke Portrait di menu utama
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
  double gridCount = 3.0; // Default lebih rapat (Samsung Style)
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissionAndFetch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // FITUR 2: Cek perubahan file saat aplikasi kembali dibuka (Auto Refresh)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchVideos();
    }
  }

  // FITUR 1: Izin otomatis saat dibuka pertama kali
  Future<void> _requestPermissionAndFetch() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtended();
    if (ps.isAuth) {
      _fetchVideos();
      // FITUR 2: Pasang observer otomatis buat deteksi file dihapus/tambah
      PhotoManager.addChangeCallback((_) => _fetchVideos());
      PhotoManager.startChangeNotify();
    } else {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter Search
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
                    // FITUR 6: Pinch-to-zoom (Adjust Ukuran List)
                    onScaleUpdate: (details) {
                      setState(() {
                        if (details.scale > 1.1) gridCount = 2.0; // Zoom In -> Besar
                        if (details.scale < 0.9) gridCount = 4.0; // Zoom Out -> Kecil
                      });
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.all(4), // FITUR 8: Jarak rapat
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
                            HapticFeedback.mediumImpact();
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
                          child: AnimatedContainer( // FITUR 7: Animasi pilih halus
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              border: isSelected ? Border.all(color: const Color(0xFF0377FF), width: 3) : null,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: AssetThumbnail(asset: video),
                                ),
                                if (isSelectionMode) Positioned(top: 5, left: 5, child: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: Colors.white, size: 24)),
                                Positioned(bottom: 5, right: 5, child: Text(_formatDuration(video.videoDuration), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
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

  // --- UI Components ---
  AppBar _buildNormalAppBar() => AppBar(
    title: const Text("Video", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
    actions: [IconButton(icon: const Icon(Icons.more_vert), onPressed: () {})],
  );

  AppBar _buildSelectionAppBar() => AppBar(
    backgroundColor: Colors.white,
    leading: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { isSelectionMode = false; selectedVideos.clear(); })),
    title: Text("${selectedVideos.length} Terpilih", style: const TextStyle(color: Colors.black)), // FITUR 7: Indikator jumlah
  );

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: TextField(
      onChanged: (val) => setState(() => searchQuery = val),
      decoration: InputDecoration(
        hintText: "Cari video...",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
        contentPadding: EdgeInsets.zero,
      ),
    ),
  );

  Widget _buildBottomActions() => BottomAppBar(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _bottomItem(Icons.share, "Berbagi", () async {
          List<XFile> files = [];
          for (var v in selectedVideos) { final f = await v.file; if(f != null) files.add(XFile(f.path)); }
          Share.shareXFiles(files);
        }),
        if (selectedVideos.length == 1) _bottomItem(Icons.edit, "Ubah Nama", () {}), // FITUR 7: Rename 1 file saja
        _bottomItem(Icons.delete, "Hapus", () {}),
        _bottomItem(Icons.folder_open, "Pindahkan", () {}),
      ],
    ),
  );

  Widget _bottomItem(IconData icon, String label, VoidCallback tap) => InkWell(
    onTap: tap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 22), Text(label, style: const TextStyle(fontSize: 10))]),
  );

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, "0");
    return d.inHours > 0 ? "${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}" : "${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}";
  }
}

// --- PLAYER SCREEN (FITUR 3, 4, 5) ---
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
  bool _isLocked = false;

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
        Future.delayed(const Duration(seconds: 3), () => setState(() => _showControls = false));
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
                // Layer Video
                Center(child: AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: VideoPlayer(_controller!))),
                
                // FITUR 5: Gestur (Tap & Swipe)
                GestureDetector(
                  onTap: () => setState(() => _showControls = !_showControls),
                  onDoubleTapDown: (details) {
                    // FITUR 4: Indikator Double Tap
                    _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                    setState(() {});
                  },
                  onVerticalDragUpdate: (details) async {
                    if (details.globalPosition.dx > MediaQuery.of(context).size.width / 2) {
                      _volume = (_volume - details.delta.dy / 200).clamp(0.0, 1.0);
                      _controller!.setVolume(_volume);
                    } else {
                      _brightness = (_brightness - details.delta.dy / 200).clamp(0.0, 1.0);
                      await ScreenBrightness().setScreenBrightness(_brightness);
                    }
                    setState(() {});
                  },
                ),

                // FITUR 3: UI Playback Lengkap
                if (_showControls) ...[
                  _buildHeader(),
                  _buildCenterIndicator(),
                  _buildBottomControls(),
                ],
              ],
            ),
    );
  }

  Widget _buildHeader() => Positioned(
    top: 40, left: 10, right: 10,
    child: Row(
      children: [
        IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        Expanded(child: Text(widget.video.title ?? "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
      ],
    ),
  );

  Widget _buildCenterIndicator() => Center(
    child: Icon(_controller!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white70, size: 80),
  );

  Widget _buildBottomControls() => Positioned(
    bottom: 50, left: 20, right: 20,
    child: Column(
      children: [
        VideoProgressIndicator(_controller!, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Color(0xFF0377FF))),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(_controller!.value.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
            Row(children: [
              IconButton(icon: const Icon(Icons.screen_rotation, color: Colors.white), onPressed: () {
                SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.portraitUp]);
              }),
              IconButton(icon: const Icon(Icons.lock_outline, color: Colors.white), onPressed: () {}),
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
      builder: (_, snap) => snap.hasData ? Image.memory(snap.data!, fit: BoxFit.cover) : Container(color: Colors.grey[300]),
    );
  }
}
