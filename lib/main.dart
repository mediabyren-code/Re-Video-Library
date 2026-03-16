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

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    // PAKAI CARA PALING UMUM: requestPermission()
    final PermissionState ps = await PhotoManager.requestPermissionExtended();
    
    if (ps.isAuth || ps.hasAccess) {
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.video,
      );
      if (paths.isNotEmpty) {
        final List<AssetEntity> entities = await paths[0].getAssetListRange(
          start: 0,
          end: 100,
        );
        setState(() => videoList = entities);
      }
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
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text("Re Video Library", 
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ),
      body: videoList.isEmpty
          ? const Center(child: Text("Mencari video di HP..."))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
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
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.play_circle_fill, color: Color(0xFF0377FF), size: 48),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(videoList[index].title ?? "Video", 
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  ],
                );
              },
            ),
      bottomNavigationBar: Container(
        height: 30,
        alignment: Alignment.center,
        child: const Text("Hello from planet Project", 
          style: TextStyle(fontSize: 10, color: Colors.grey)),
      ),
    );
  }
}
