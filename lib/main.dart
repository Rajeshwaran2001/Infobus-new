import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'src/navigation_controls.dart'; // Removed 'webview_stack.dart' as it's unused

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false, // Remove the debug banner
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
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true; // Show loader
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false; // Hide loader
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              isLoading = false; // Hide loader on error
            });
          },
        ),
      )
      ..loadRequest(Uri.parse('https://infobus.in/new-view'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('InfoBus', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFDE1A2A), // Added 'const'
        iconTheme: const IconThemeData(color: Colors.white), // Added 'const'
        centerTitle: true,
        actions: [
          NavigationControls(controller: controller),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller), // WebView content

          // Loader Overlay
          if (isLoading)
            Container(
              color: Colors.white.withOpacity(0.7), // Background overlay
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.red), // Loading spinner
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
