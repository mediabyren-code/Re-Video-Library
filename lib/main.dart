import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';

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
      theme: ThemeData(primaryColor: const Color(0xFF0377FF), useMaterial3: true),
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
    _initApp();
  }

  Future<void> _initApp() async {
    // Minta izin pakai cara standar Android dulu
    var status = await Permission.videos.request();
    
    if (status.isGranted) {
      // Kalau diizinkan, baru panggil photo_manager tanpa embel-embel Extended
      try {
        final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
          type: RequestType.video,
        );
        if (paths.isNotEmpty) {
          final List<AssetEntity> entities = await paths[0].getAssetListRange(
            start: 0, end: 100,
          );
          setState(() {
            videoList = entities;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } catch (e) {
        setState(() => _isLoading = false);
      }
    } else {
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0377FF),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text("Re Video Library",
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0377FF)))
          : videoList.isEmpty
              ? const Center(child: Text("Klik 'Izinkan' atau Video tidak ditemukan"))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.85),
                  itemCount: videoList.length,
                  itemBuilder: (context, index) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.play_circle_filled, color: Color(0xFF0377FF), size: 40),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(videoList[index].title ?? "Video", 
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                      ],
                    );
                  },
                ),
      bottomNavigationBar: Container(
        height: 30,
        alignment: Alignment.center,
        child: const Text("Hello from planet Project", style: TextStyle(fontSize: 9, color: Colors.grey)),
      ),
    );
  }
}
