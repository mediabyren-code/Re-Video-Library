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
  List<AssetPathEntity> folderList = [];
  Set<AssetEntity> selectedVideos = {};
  bool isSelectionMode = false;
  bool _isLoading = true;
  bool isGridView = true;
  bool isFolderMode = false; // FITUR: Toggle Semua/Folder
  double gridCount = 3.0; 
  String searchQuery = "";
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchFocus.dispose();
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
      final List<AssetEntity> entities = await paths[0].getAssetListRange(start: 0, end: 1000);
      if (mounted) setState(() { 
        videoList = entities; 
        folderList = paths;
        _isLoading = false; 
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredVideos = videoList.where((v) => (v.title ?? "").toLowerCase().contains(searchQuery.toLowerCase())).toList();

    return WillPopScope(
      onWillPop: () async {
        if (isSelectionMode) {
          setState(() { isSelectionMode = false; selectedVideos.clear(); });
          return false;
        }
        if (_searchFocus.hasFocus) {
          _searchFocus.unfocus(); // FITUR: Keyboard tutup, gak keluar app
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (!isSelectionMode) _buildSearchBar(),
                  _buildSubHeader(), // Indikator jumlah & Mode
                  Expanded(
                    child: isFolderMode ? _buildFolderList() : (isGridView ? _buildGrid(filteredVideos) : _buildList(filteredVideos)),
                  ),
                ],
              ),
        bottomNavigationBar: isSelectionMode ? _buildBottomActions() : null,
      ),
    );
  }

  // --- UI COMPONENTS ---

  AppBar _buildNormalAppBar() => AppBar(
    title: const Text("Video", style: TextStyle(fontWeight: FontWeight.bold)),
    actions: [
      IconButton(
        icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
        onPressed: () => setState(() => isGridView = !isGridView),
      ),
    ],
  );

  AppBar _buildSelectionAppBar() => AppBar(
    leading: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { isSelectionMode = false; selectedVideos.clear(); })),
    title: Text("${selectedVideos.length} Video terpilih"), // Indikator jumlah dipilih
  );

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.all(16),
    child: TextField(
      focusNode: _searchFocus,
      onChanged: (val) => setState(() => searchQuery = val),
      decoration: InputDecoration(
        hintText: "Cari video...",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
      ),
    ),
  );

  Widget _buildSubHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("${videoList.length} Video", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)), // Indikator total
        Row(
          children: [
            TextButton(onPressed: () => setState(() => isFolderMode = false), child: Text("Semua", style: TextStyle(fontWeight: !isFolderMode ? FontWeight.bold : FontWeight.normal))),
            TextButton(onPressed: () => setState(() => isFolderMode = true), child: Text("Folder", style: TextStyle(fontWeight: isFolderMode ? FontWeight.bold : FontWeight.normal))),
          ],
        )
      ],
    ),
  );

  Widget _buildGrid(List<AssetEntity> list) => GridView.builder(
    padding: const EdgeInsets.all(4),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: gridCount.toInt(), mainAxisSpacing: 4, crossAxisSpacing: 4),
    itemCount: list.length,
    itemBuilder: (context, index) => _videoItem(list[index], list, index),
  );

  Widget _buildList(List<AssetEntity> list) => ListView.builder(
    itemCount: list.length,
    itemBuilder: (context, index) {
      final v = list[index];
      return ListTile(
        leading: SizedBox(width: 80, child: AssetThumbnail(asset: v)),
        title: Text(v.title ?? "Video", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), // Bold judul
        subtitle: Text("${v.width}x${v.height} | ${v.mimeType?.toUpperCase()}", style: const TextStyle(fontSize: 11, color: Colors.grey)), // Kecil format
        trailing: Text(_formatDuration(v.videoDuration)),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SamsungPlayerScreen(video: v, playlist: list, currentIndex: index))),
      );
    },
  );

  Widget _buildFolderList() => ListView.builder(
    itemCount: folderList.length,
    itemBuilder: (context, index) => ListTile(
      leading: const Icon(Icons.folder, size: 40, color: Colors.amber),
      title: Text(folderList[index].name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {}, // Tambahkan detail folder jika perlu
    ),
  );

  Widget _videoItem(AssetEntity video, List<AssetEntity> playlist, int index) {
    final isSelected = selectedVideos.contains(video);
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        setState(() { isSelectionMode = true; selectedVideos.add(video); });
      },
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
          if (isSelected) Container(color: Colors.blue.withOpacity(0.4), child: const Center(child: Icon(Icons.check_circle, color: Colors.white, size: 30))),
        ],
      ),
    );
  }

  Widget _buildBottomActions() => BottomAppBar(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _actionBtn(Icons.share, "Bagikan", () async {
          List<XFile> files = [];
          for (var v in selectedVideos) { final f = await v.file; if(f != null) files.add(XFile(f.path)); }
          Share.shareXFiles(files);
        }),
        if (selectedVideos.length == 1) _actionBtn(Icons.edit, "Ubah Nama", () {}), // Muncul hanya 1 file
        _actionBtn(Icons.delete, "Hapus", () {}),
      ],
    ),
  );

  Widget _actionBtn(IconData icon, String label, VoidCallback tap) => InkWell(onTap: tap, child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon), Text(label, style: const TextStyle(fontSize: 10))]));

  String _formatDuration(Duration d) => "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
}

// --- PLAYER & THUMBNAIL (SAMA SEPERTI SEBELUMNYA TAPI FIX MENU) ---

class AssetThumbnail extends StatelessWidget {
  final AssetEntity asset;
  const AssetThumbnail({super.key, required this.asset});
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailData,
      builder: (_, snap) => snap.hasData ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(snap.data!, fit: BoxFit.cover)) : Container(color: Colors.black12),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _initPlayer(widget.playlist[_currentIndex]);
  }

  Future<void> _initPlayer(AssetEntity video) async {
    if (_controller != null) await _controller!.dispose();
    final file = await video.file;
    if (file != null) {
      _controller = VideoPlayerController.file(file)..initialize().then((_) {
        setState(() { _controller!.play(); });
        _controller!.addListener(() { if(mounted) setState(() {}); });
      });
    }
  }

  @override
  void dispose() { _controller?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  Positioned(
                    top: 40, left: 10, right: 10,
                    child: Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                        Expanded(child: Text(widget.playlist[_currentIndex].title ?? "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                        PopupMenuButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          itemBuilder: (context) => [
                            PopupMenuItem(child: const Text("Bagikan"), onTap: () async {
                              final f = await widget.playlist[_currentIndex].file;
                              if(f != null) Share.shareXFiles([XFile(f.path)]);
                            }),
                            const PopupMenuItem(child: Text("Ubah Nama")), // Logika rename bisa ditambah dialog
                            const PopupMenuItem(child: Text("Hapus")), // Logika hapus
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white, size: 40), onPressed: () { if (_currentIndex > 0) { _currentIndex--; _initPlayer(widget.playlist[_currentIndex]); } }),
                      IconButton(icon: Icon(_controller!.value.isPlaying ? Icons.pause_circle : Icons.play_circle, color: Colors.white, size: 70), onPressed: () => setState(() { _controller!.value.isPlaying ? _controller!.pause() : _controller!.play(); })),
                      IconButton(icon: const Icon(Icons.skip_next, color: Colors.white, size: 40), onPressed: () { if (_currentIndex < widget.playlist.length - 1) { _currentIndex++; _initPlayer(widget.playlist[_currentIndex]); } }),
                    ],
                  ),
                  Positioned(
                    bottom: 40, left: 20, right: 20,
                    child: Slider(
                      value: _controller!.value.position.inSeconds.toDouble().clamp(0, _controller!.value.duration.inSeconds.toDouble()),
                      max: _controller!.value.duration.inSeconds.toDouble(),
                      onChanged: (val) => _controller!.seekTo(Duration(seconds: val.toInt())),
                    ),
                  )
                ],
              ],
            ),
    );
  }

  String _formatDuration(Duration d) => "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
}
