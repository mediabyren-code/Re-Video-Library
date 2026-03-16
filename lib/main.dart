import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

void main() => runApp(const SamsungVideoApp());

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

  // Fungsi Scan Video Terbaru & Anti-Error
  _fetchVideos() async {
    // Cara panggil izin terbaru di PhotoManager
    final PermissionState ps = await PhotoManager.requestPermissionExtended();
    
    if (ps.isAuth || ps.hasAccess) {
      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
      );
      
      if (albums.isNotEmpty) {
        // Ambil 50 video terbaru
        List<AssetEntity> videos = await albums[0].getAssetListRange(start: 0, end: 50);
        setState(() {
          videoList = videos;
        });
      }
    } else {
      // Jika ditolak, minta lagi
      PhotoManager.openSetting();
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
          child: const Text(
            "Re Video Library",
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: videoList.isEmpty 
          ? const Center(child: Text("Memuat video atau Izin ditolak..."))
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, 
                mainAxisSpacing: 10, 
                crossAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: videoList.length,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Center(
                          child: Icon(Icons.play_circle_fill, color: Color(0xFF0377FF), size: 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      videoList[index].title ?? "Video Unnamed",
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar: Container(
        height: 40,
        alignment: Alignment.center,
        child: const Text(
          "Hello from planet Project",
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ),
    );
  }
}
