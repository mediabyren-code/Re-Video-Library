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
  bool isGridView = true; // FITUR: Toggle Grid/List
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
    if (state == AppLifecycleState.resumed) _fetchVideos();
  }

  Future<void> _checkPermission() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth || ps.hasAccess) {
      _fetchVideos();
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
      if (mounted) setState(() { videoList = entities; _isLoading = false; });
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
                    // FITUR: Zoom In/Out 3 Level (Kecil, Sedang, Besar)
                    onScaleEnd: (details) {
                      setState(() {
                        if (gridCount > 2.0) gridCount = 2.0; // Besar
                        else if (gridCount == 2.0) gridCount = 3.0; // Sedang
                        else gridCount = 4.0; // Kecil
                      });
                    },
                    child: isGridView ? _buildGrid(filteredVideos) : _buildList(filteredVideos),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: isSelectionMode ? _buildBottomActions() : null,
    );
  }

  // --- UI HOME COMPONENTS ---
  AppBar _buildNormalAppBar() => AppBar(
    title: const Text("Video", style: TextStyle(fontWeight: FontWeight.bold)),
    actions: [
      // FITUR: Pilihan Preview (Grid/List)
      IconButton(
        icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
        onPressed: () => setState(() => isGridView = !isGridView),
      ),
      IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
    ],
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

  Widget _buildGrid(List<AssetEntity> list) => GridView.builder(
    padding: const EdgeInsets.all(4),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: gridCount.toInt(),
      mainAxisSpacing: 4, crossAxisSpacing: 4,
    ),
    itemCount: list.length,
    itemBuilder: (context, index) => _videoItem(list[index], list, index),
  );

  Widget _buildList(List<AssetEntity> list) => ListView.builder(
    itemCount: list.length,
    itemBuilder: (context, index) => ListTile(
      leading: SizedBox(width: 80, child: AssetThumbnail(asset: list[index])),
      title: Text(list[index].title ?? "Video", maxLines: 1),
      subtitle: Text("${list[index].width}x${list[index].height} | ${_formatDuration(list[index].videoDuration)}"),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SamsungPlayerScreen(video: list[index], playlist: list, currentIndex: index))),
    ),
  );

  Widget _videoItem(AssetEntity video, List<AssetEntity> playlist, int index) {
    final isSelected = selectedVideos.contains(video);
    return GestureDetector(
      onLongPress: () => setState(() { isSelectionMode = true; selectedVideos.add(video); }),
      onTap: () {
        if (isSelectionMode) {
          setState(() { isSelected ? selectedVideos.remove(video) : selectedVideos.add(video); if (selectedVideos.isEmpty) isSelectionMode = false; });
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => SamsungPlayerScreen(video: video, playlist: playlist, currentIndex: index)));
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          AssetThumbnail(asset: video),
          if (isSelectionMode) Positioned(top: 5, left: 5, child: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildBottomActions() => BottomAppBar(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(icon: const Icon(Icons.share), onPressed: () async {
          List<XFile> files = [];
          for (var v in selectedVideos) { final f = await v.file; if(f != null) files.add(XFile(f.path)); }
          Share.shareXFiles(files);
        }),
        IconButton(icon: const Icon(Icons.delete), onPressed: () {}),
      ],
    ),
  );

  String _formatDuration(Duration d) => "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
}

// --- PLAYER SCREEN (MEGA UPDATE) ---
class SamsungPlayerScreen extends StatefulWidget {
  final AssetEntity video;
  final List<AssetEntity> playlist;
  final int currentIndex;
  const SamsungPlayerScreen({super.key, required this.video, required this.playlist, required this.currentIndex});

  @override
  State<SamsungPlayerScreen> createState() => _SamsungPlayerScreenState();
}

class _SamsungPlayerScreenState extends State<SamsungPlayerScreen> {
  VideoPlayerController? _controller;
  bool _showControls = true;
  late int _currentIndex;
  bool _isLandscape = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _initPlayer(widget.playlist[_currentIndex]);
  }

  Future<void> _initPlayer(AssetEntity video) async {
    _controller?.dispose();
    final file = await video.file;
    if (file != null) {
      _controller = VideoPlayerController.file(file)..initialize().then((_) {
        setState(() { _controller!.play(); });
        _controller!.addListener(() => setState(() {}));
      });
    }
  }

  void _toggleRotate() {
    setState(() {
      _isLandscape = !_isLandscape;
      if (_isLandscape) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
      } else {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isLandscape) { _toggleRotate(); return false; }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _controller == null || !_controller!.value.isInitialized
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showControls = !_showControls),
                    child: Center(child: AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: VideoPlayer(_controller!))),
                  ),
                  if (_showControls) ...[
                    _buildTopBar(),
                    _buildNavButtons(),
                    _buildBottomUI(),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildTopBar() => Positioned(
    top: 40, left: 10, right: 10,
    child: Row(
      children: [
        IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        Expanded(child: Text(widget.playlist[_currentIndex].title ?? "Video", style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
        // FITUR: Titik 3 (Rename, Delete, Share)
        PopupMenuButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          itemBuilder: (context) => [
            PopupMenuItem(child: const Text("Bagikan"), onTap: () async {
              final f = await widget.playlist[_currentIndex].file;
              if(f != null) Share.shareXFiles([XFile(f.path)]);
            }),
            const PopupMenuItem(child: Text("Ubah Nama")),
            const PopupMenuItem(child: Text("Hapus")),
          ],
        ),
      ],
    ),
  );

  Widget _buildNavButtons() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white, size: 50), onPressed: () {
        if (_currentIndex > 0) { _currentIndex--; _initPlayer(widget.playlist[_currentIndex]); }
      }),
      IconButton(
        icon: Icon(_controller!.value.isPlaying ? Icons.pause_circle : Icons.play_circle, color: Colors.white, size: 80),
        onPressed: () => setState(() => _controller!.value.isPlaying ? _controller!.pause() : _controller!.play()),
      ),
      IconButton(icon: const Icon(Icons.skip_next, color: Colors.white, size: 50), onPressed: () {
        if (_currentIndex < widget.playlist.length - 1) { _currentIndex++; _initPlayer(widget.playlist[_currentIndex]); }
      }),
    ],
  );

  Widget _buildBottomUI() => Positioned(
    bottom: 40, left: 20, right: 20,
    child: Column(
      children: [
        Slider(
          value: _controller!.value.position.inSeconds.toDouble(),
          max: _controller!.value.duration.inSeconds.toDouble(),
          onChanged: (val) => _controller!.seekTo(Duration(seconds: val.toInt())),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(_controller!.value.position), style: const TextStyle(color: Colors.white)),
            IconButton(icon: const Icon(Icons.screen_rotation, color: Colors.white), onPressed: _toggle
