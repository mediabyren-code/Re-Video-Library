import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

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
      title: 'Re Video Library',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0377FF)),
        useMaterial3: true,
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    // JALUR ALTERNATIF: Langsung panggil getAssetPathList. 
    // Di versi terbaru, fungsi ini otomatis memicu pop-up izin jika belum ada.
    try {
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.video,
      );
      
      if (paths.isNotEmpty) {
        final List<AssetEntity> entities = await paths[0].getAssetListRange(
          start: 0,
          end: 100,
        );
        setState(() {
          videoList = entities;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      // Jika gagal/ditolak, buka setting
      PhotoManager.openSetting();
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0377FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            "Re Video Library",
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : videoList.isEmpty
              ? const Center(child: Text("Video tidak ditemukan.\nBerikan izin akses galeri.", textAlign: TextAlign.center))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 15, crossAxisSpacing: 15, childAspectRatio: 0.8,
                  ),
                  itemCount: videoList.length,
                  itemBuilder: (context, index) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.play_circle_fill, color: Color(0xFF0377FF), size: 50),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          videoList[index].title ?? "Video ${index + 1}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
