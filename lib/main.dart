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

  _fetchVideos() async {
    final PermissionState ps = await PhotoManager.requestPermission();
    if (ps.isAuth) {
      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(type: RequestType.video);
      if (albums.isNotEmpty) {
        List<AssetEntity> videos = await albums[0].getAssetListRange(start: 0, end: 100);
        setState(() => videoList = videos);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFF0377FF), borderRadius: BorderRadius.circular(4)),
          child: const Text("Re Video Library", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ),
      body: videoList.isEmpty 
          ? const Center(child: Text("Tidak ada video / Izin belum diberikan"))
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10),
              itemCount: videoList.length,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(15)),
                        child: const Center(child: Icon(Icons.play_circle_fill, color: Color(0xFF0377FF), size: 40)),
                      ),
                    ),
                    Text(videoList[index].title ?? "Video", style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  ],
                );
              },
            ),
       bottomNavigationBar: const Padding(
         padding: EdgeInsets.all(8.0),
         child: Text("Hello from planet Project", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey)),
       ),
    );
  }
}
