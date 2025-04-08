import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:http/http.dart' as http;
import 'src/navigation_controls.dart';
import 'package:just_audio/just_audio.dart';
import 'package:intl/intl.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestStoragePermission();
    });

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) async {
          final Map<String, dynamic> receivedData = jsonDecode(message.message);
          String action = receivedData['message'];

          if (action == 'downloadBlob') {
            final base64Data = receivedData['data'].split(',')[1];
            final fileName = receivedData['filename'];

            final bytes = base64Decode(base64Data);
            final downloadDir = Directory('/storage/emulated/0/Download');
            final file = File('${downloadDir.path}/$fileName');
            await file.writeAsBytes(bytes);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Blob file saved to: ${file.path}'),
                action: SnackBarAction(
                  label: 'Open',
                  onPressed: () {
                    OpenFile.open(file.path);
                  },
                ),
              ),
            );
          } else if (action == 'openFlutterScreen') {
            String radioUrl = receivedData['radio'];
            String adName = receivedData['ad_name'];

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SecondScreen(
                  radioUrl: radioUrl,
                  adName: adName,
                ),
              ),
            );
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) async {
            if (request.url.endsWith('.xlsx')) {
              _downloadFile(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (_) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (_) async {
            setState(() => isLoading = false);

            await controller.runJavaScript('''
            setTimeout(() => {
              document.querySelectorAll('a').forEach(a => {
                a.addEventListener('click', function(e) {
                  const href = a.getAttribute('href');
                  if (href && href.startsWith('blob:')) {
                    e.preventDefault();
                    e.stopPropagation();
                    fetch(href)
                      .then(response => response.blob())
                      .then(blob => {
                        const reader = new FileReader();
                        reader.onloadend = function() {
                          const base64data = reader.result;
                          FlutterChannel.postMessage(JSON.stringify({
                            message: 'downloadBlob',
                            data: base64data,
                            filename: 'download.xlsx'
                          }));
                        };
                        reader.readAsDataURL(blob);
                      });
                  }
                });
              });
            }, 1000);
          ''');
          },
          onWebResourceError: (_) => setState(() => isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse('https://portal.busads.in/new-view'));
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        final fallback = await Permission.storage.request();
        if (!fallback.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')),
          );
        }
      }
    }
  }

  Future<void> _downloadFile(String url) async {
    try {
      final downloadDir = Directory('/storage/emulated/0/Download');
      final fileName = url.split('/').last;
      final filePath = '${downloadDir.path}/$fileName';

      final response = await http.get(Uri.parse(url));
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File downloaded to: $filePath'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () {
              OpenFile.open(filePath);
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('InfoBus', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFDE1A2A),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading)
            Container(
              color: Colors.white.withOpacity(0.7),
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
  final String? radioUrl;
  final String? adName;
  const SecondScreen({Key? key, this.radioUrl, this.adName}) : super(key: key);

  @override
  State<SecondScreen> createState() => _SecondScreenState();
}

class _SecondScreenState extends State<SecondScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  bool isLoading = true;
  final ScrollController _scrollController = ScrollController();

  String streamUrl = "";
  String? errorMessage;
  bool isApiLoading = false;
  List<ScheduleItem> scheduleList = [];

  @override
  void initState() {
    super.initState();
    _updateStreamUrl();
    _startPlaying();
    fetchScheduleData();

    _audioPlayer.playerStateStream.listen((state) {
      final playing = state.playing;
      final processing = state.processingState;

      setState(() {
        isPlaying = playing && processing == ProcessingState.ready;
        isLoading = processing == ProcessingState.loading ||
            processing == ProcessingState.buffering;
      });
    });

    print("Received radio URL: ${widget.radioUrl}");
    print("Received ad name: ${widget.adName}");
  }

  void _updateStreamUrl() {
    setState(() {
      streamUrl = "${widget.radioUrl}";
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startPlaying() async {
    try {
      setState(() {
        isLoading = true;
      });
      await _audioPlayer.setUrl(streamUrl);
      await _audioPlayer.play();
    } catch (e) {
      print("Error playing audio: $e");
      setState(() {
        isLoading = false;
        isPlaying = false;
      });
    }
  }

  void _togglePlayPause() async {
    if (isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  void _stopAndExit() {
    _audioPlayer.stop();
    exit(0);
  }

  Future<void> fetchScheduleData() async {
    setState(() {
      isApiLoading = true;
      errorMessage = null;
      scheduleList = [];
    });

    final now = DateTime.now();
    final timeOnly = DateFormat.jm().format(now);

    final data = jsonEncode({
      "adname": widget.adName,
      "time": timeOnly, // Or use a fixed time like "5:25 PM"
    });

    final url = Uri.parse("https://portal.busads.in/api/radio");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: data,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['message'] != null) {
          // Show no data message
          setState(() {
            errorMessage = "No data to display.";
          });
        } else {
          setState(() {
            scheduleList = (decoded as List)
                .map((json) => ScheduleItem.fromJson(json))
                .toList();
          });
        }
      } else {
        setState(() {
          errorMessage = "Failed to get schedule";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Failed to get schedule";
      });
    } finally {
      setState(() {
        isApiLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("InfoBus Radio 📻",
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFDE1A2A),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.redAccent.shade100, Colors.redAccent.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 20),
                child: Image.asset(
                  'images/fm_radio.png',
                  width: 380,
                  height: 80,
                  fit: BoxFit.scaleDown,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                      child: isLoading
                          ? const SizedBox(
                              width: 60,
                              height: 60,
                              child:
                                  CircularProgressIndicator(color: Colors.red),
                            )
                          : IconButton(
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
                    const SizedBox(width: 30),
                    Padding(
                      padding: const EdgeInsets.only(top: 40.0),
                      child: IconButton(
                        icon: const Icon(
                          Icons.stop_circle,
                          size: 80,
                          color: Colors.red,
                        ),
                        onPressed: _stopAndExit,
                      ),
                    )
                  ],
                ),
              ),
              Text(
                isPlaying ? "Playing... 🎶" : "Paused ⏸️",
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage != null
                        ? Center(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.white),
                            ),
                          )
                        : scheduleList.isEmpty
                            ? const Center(
                                child: Text("No data to display.",
                                    style: const TextStyle(
                                        fontSize: 80, color: Colors.white)),
                              )
                            : SingleChildScrollView(
                                controller: _scrollController,
                                scrollDirection: Axis.vertical,
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Table(
                                    border:
                                        TableBorder.all(color: Colors.black),
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
                                                  color: Colors.black,
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
                                                  color: Colors.black,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      ...scheduleList.map((item) {
                                        final isNext = item.next == true;
                                        final isCustomer =
                                            item.isCustomer == true;

                                        return TableRow(
                                          decoration: BoxDecoration(
                                            color: isNext
                                                ? Colors.yellow.withOpacity(0.4)
                                                : null, // Highlight if next
                                          ),
                                          children: [
                                            TableCell(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Text(
                                                  item.time,
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight
                                                        .bold, // Always bold for time
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                            TableCell(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Text(
                                                  item.name,
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: isCustomer
                                                        ? FontWeight.bold
                                                        : FontWeight
                                                            .normal, // Bold if isCustomer
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                ),
                              ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class ScheduleItem {
  final String time;
  final String name;
  final bool next;
  final bool isCustomer;

  ScheduleItem({
    required this.time,
    required this.name,
    required this.next,
    required this.isCustomer,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      time: json['Time'] ?? '',
      name: json['Name'] ?? '',
      next: json['next_schedule']?.toString().toLowerCase() == 'true',
      isCustomer:
          json['upcoming_customer_schedule']?.toString().toLowerCase() ==
              'true',
    );
  }
}
