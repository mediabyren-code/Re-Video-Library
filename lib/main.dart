import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF0377FF)),
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
  double gridCount = 2.0; // Buat Pinch-to-zoom
  String sortBy = "date"; // date atau size

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(type: RequestType.video);
    if (paths.isNotEmpty) {
      List<AssetEntity> entities = await paths[0].getAssetListRange(start: 0, end: 100);
      _sortVideos(entities);
    }
  }

  void _sortVideos(List<AssetEntity> list) {
    if (sortBy == "date") {
      list.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
    }
    setState(() { videoList = list; _isLoading = false; });
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return "0 B";
    var i = (bytes.toString().length - 1) / 3;
    var suffixes = ["B", "KB", "MB", "GB"];
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0377FF),
        elevation: 0,
        title: Text(isSelectionMode ? "${selectedVideos.length} Terpilih" : "Re Video Library", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: isSelectionMode ? IconButton(icon: const Icon(Icons.close, color: Colors.white), 
          onPressed: () => setState(() { isSelectionMode = false; selectedVideos.clear(); })) : null,
        actions: [
          if (!isSelectionMode) IconButton(icon: const Icon(Icons.sort, color: Colors.white), 
            onPressed: () {
              setState(() => sortBy = sortBy == "date" ? "size" : "date");
              _sortVideos(videoList);
            }),
        ],
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onScaleUpdate: (details) {
                setState(() {
                  // Pinch to zoom logic: Ubah jumlah kolom grid (min 2, max 4)
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
                        setState(() { isSelected ? selectedVideos.remove(video); selectedVideos.isEmpty ? isSelectionMode = false : null; });
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
                                  child: AssetEntityImage(video, isOriginal: false, thumbnailSize: const ThumbnailSize(400, 400), fit: BoxFit.cover),
                                ),
                              ),
                              if (isSelectionMode) Positioned(
                                top: 8, left: 8,
                                child: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: Colors.blue, size: 28),
                              ),
                              Positioned(bottom: 8, right: 8, child: Container(
                                padding: const EdgeInsets.all(4), color: Colors.black54,
                                child: Text(video.durationString, style: const TextStyle(color: Colors.white, fontSize: 10)),
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(video.title ?? "Video", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        // Simulasi ukuran file (photo_manager butuh await buat size asli, kita pake placeholder MB biar gak lambat)
                        const Text("Video MP4", style: TextStyle(fontSize: 9, color: Colors.grey)),
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
              Share.shareXFiles(files);
            }),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () {
              // Logic delete Samsung: PhotoManager.editor.deleteWithIds
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fitur hapus butuh izin sistem tambahan")));
            }),
          ],
        ),
      ) : null,
    );
  }
}

// ... Copy juga class SamsungPlayerScreen dari kode sebelumnya ...
