import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'src/navigation_controls.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert'; 

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const WebViewApp(),
    ),
  );
}

class WebViewApp extends StatefulWidget {
  const WebViewApp({super.key});

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

class _WebViewAppState extends State<WebViewApp> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setBackgroundColor(const Color(0x00000000))
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
    'FlutterChannel',
    onMessageReceived: (JavaScriptMessage message) {
      final Map<String, dynamic> receivedData = jsonDecode(message.message);
      String action = receivedData['message'];
      String? data = receivedData['district'];

      if (action == "openFlutterScreen") {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SecondScreen(data: data)),
        );
      }
    },
  )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse('https://portal.busads.in/new-view'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('InfoBus', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFDE1A2A),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        actions: [
          NavigationControls(controller: controller),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            Container(
              color: Colors.white.withAlpha((0.7 * 255).toInt()),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.red),
                    SizedBox(height: 10),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SecondScreen extends StatefulWidget {
  final String? data;
  const SecondScreen({Key? key, this.data}) : super(key: key);

  @override
  State<SecondScreen> createState() => _SecondScreenState();
}

class _SecondScreenState extends State<SecondScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  bool isLoading = true;
  final ScrollController _scrollController = ScrollController();

  String streamUrl = "";

  @override
  void initState() {
    super.initState();
    _updateStreamUrl();
    _startPlaying();
    print("Received data: ${widget.data}");
  }

  void _updateStreamUrl() {
    setState(() {
      streamUrl = "https://cast3.asurahosting.com/proxy/info_dindugal/stream";
    });
  }

   @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startPlaying() async {
    setState(() {
      isLoading = true;
    });

    try {
      await _audioPlayer.setUrl(streamUrl);
      await _audioPlayer.play();
      setState(() {
        isPlaying = true;
      });
    } catch (e) {
      print("Error playing audio: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  void _togglePlayPause() async {
    if (isPlaying) {
      await _audioPlayer.pause();
    } else {
      setState(() {
        isLoading = true;
      });

      await _audioPlayer.setUrl(streamUrl);
      await _audioPlayer.play();
    }

    setState(() {
      isPlaying = !isPlaying;
      isLoading = false;
    });
  }

  void _stopAndExit() {
    _audioPlayer.stop();
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("InfoBus Radio",
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFDE1A2A),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red, Colors.deepOrangeAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  "InfoBus Radio 📻",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Radio Logo
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Image.asset(
                  'images/fm_radio.png',
                  width: 180,
                  height: 100,
                  fit: BoxFit.scaleDown,
                ),
              ),

              // Play / Pause Buttons with Animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPlaying ? Colors.greenAccent : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 80,
                    color: Colors.red,
                  ),
                  onPressed: _togglePlayPause,
                ),
              ),

              const SizedBox(height: 10),

              // Status Text
              Text(
                isPlaying ? "Playing... 🎶" : "Paused ⏸️",
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),

              const SizedBox(height: 10),

              // Soundwave Animation
              if (isPlaying)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: SizedBox(
                    height: 50,
                    child: Image.asset("images/sound_wave.gif"),
                  ),
                ),

              // Stop Button
              IconButton(
                icon: const Icon(Icons.stop_circle, size: 60, color: Colors.white),
                onPressed: _stopAndExit,
              ),

              const SizedBox(height: 20),

              // Schedule Table
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Table(
                      border: TableBorder.all(color: Colors.white),
                      columnWidths: const {
                        0: FractionColumnWidth(0.3),
                        1: FractionColumnWidth(0.7),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                          ),
                          children: [
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Time Slot",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "On Air - Content",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Example Schedule (You can replace this with dynamic data)
                        TableRow(
                          children: [
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "10:00 AM",
                                  style: TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Morning Talk Show ☕",
                                  style: TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "12:00 PM",
                                  style: TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            TableCell(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Top 10 Songs 🎶",
                                  style: TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}