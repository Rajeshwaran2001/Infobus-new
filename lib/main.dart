import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'src/navigation_controls.dart';
import 'package:audioplayers/audioplayers.dart';
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

  final Map<String, String> portMapping = {
    "RAMNAD": "7523",
    "DGL": "7698",
    "KARUR": "7710",
    "KKDI": "7519",
    "KUM": "7527",
    "Mayiladuthurai": "7182",
    "MADURAI": "7714",
    "MDU": "7714",
    "MNGDI": "7730",
    "NGL": "7738",
    "PATTU": "7531",
    "TANJ": "7589",
    "THENI": "7722",
    "TRICHY": "7597",
    "CBE": "7702",
  };

  @override
  void initState() {
    super.initState();
    _updateStreamUrl();
    _startPlaying();
    print("Received data: ${widget.data}");
  }

  void _updateStreamUrl() {
    List<String> parts = (widget.data ?? "").split(',');
    String firstPart = parts.isNotEmpty ? parts.first.trim() : "";
    String port = portMapping[firstPart] ?? "7714"; 
    setState(() {
      streamUrl = "https://luan.xyz/files/audio/nasa_on_a_mission.mp3";
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

    await _audioPlayer.setSourceUrl(streamUrl);
    await _audioPlayer.resume();

    setState(() {
      isPlaying = true;
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

      await _audioPlayer.setSourceUrl(streamUrl);
      await _audioPlayer.resume();
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
    List<Map<String, String>> schedule = [
      {"time": "6.15 AM", "content": "Indraya sinthanai"},
      {"time": "6.40 AM", "content": "Birthday wishes"},
      {"time": "7.05 AM", "content": "Indraya kural"},
      {"time": "7.40 AM", "content": "On board morning wishes"},
      {"time": "8.15 AM", "content": "Birthday wishes"},
      {"time": "8.40 AM", "content": "General awareness"},
      {"time": "9.20 AM", "content": "Birthday wishes"},
      {"time": "9.50 AM", "content": "General information"},
      {"time": "10.25 AM", "content": "Passenger alerting"},
      {"time": "10.45 AM", "content": "Driver / Crew awareness"},
      {"time": "11.15 AM", "content": "Welcome wishes"},
      {"time": "11.50 AM", "content": "Passenger - Thanking tags"},
      {"time": "12.05 PM", "content": "General information"},
      {"time": "12.40 PM", "content": "Passenger alerts"},
      {"time": "1.15 PM", "content": "General awareness"},
      {"time": "1.45 PM", "content": "General information"},
      {"time": "2.10 PM", "content": "Driver / Crew awareness"},
      {"time": "2.55 PM", "content": "Passenger - Thanking tags"},
      {"time": "3.20 PM", "content": "General information"},
      {"time": "3.45 PM", "content": "Passenger alerts"},
      {"time": "4.15 PM", "content": "Welcome wishes"},
      {"time": "4.50 PM", "content": "Passenger - Thanking tags"},
      {"time": "5.15 PM", "content": "General awareness"},
      {"time": "5.45 PM", "content": "Driver alert messages"},
      {"time": "6.20 PM", "content": "General information"},
      {"time": "6.50 PM", "content": "Birthday wishes"},
      {"time": "7.25 PM", "content": "Wedding wishes"},
      {"time": "7.40 PM", "content": "Passenger alerts"},
      {"time": "8.15 PM", "content": "General information"},
      {"time": "8.40 PM", "content": "Driver alert messages"},
      {"time": "9.10 PM", "content": "General Wishes tag"},
      {"time": "9.35 PM", "content": "Passenger - Thanking tags"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("InfoBus Radio",
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFDE1A2A),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Image.asset(
                'images/fm_radio.png',
                width: 380,
                height: 100,
                fit: BoxFit.scaleDown,
              ),
            ),
            const SizedBox(height: 10),
            isLoading
                ? const CircularProgressIndicator(color: Colors.red)
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              size: 80,
                              color: Colors.red,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: const Icon(Icons.stop_circle,
                                size: 80, color: Colors.red),
                            onPressed: _stopAndExit,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isPlaying ? "Playing..." : "Paused",
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Table(
                    border: TableBorder.all(),
                    columnWidths: const {
                      0: FractionColumnWidth(0.3),
                      1: FractionColumnWidth(0.7),
                    },
                    children: [
                      TableRow(children: [
                        TableCell(
                            child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text("Time Slot",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)))),
                        TableCell(
                            child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text("On Air - Content",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)))),
                      ]),
                      ...schedule.map((entry) => TableRow(children: [
                            TableCell(
                                child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(entry['time']!))),
                            TableCell(
                                child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(entry['content']!))),
                          ])).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
