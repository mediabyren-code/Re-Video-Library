import 'package:flutter/material.dart';

void main() {
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
        useMaterial3: true,
        primaryColor: const Color(0xFF0377FF), // Biru Samsung
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
          child: const Text(
            "Re Video Library",
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Text("Video list akan muncul di sini setelah scan", 
                style: TextStyle(color: Colors.grey[600])),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              "Hello from planet Project",
              style: TextStyle(fontSize: 10, color: Colors.grey, opacity: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
