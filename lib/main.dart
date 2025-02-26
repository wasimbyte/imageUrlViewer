import 'package:flutter/material.dart';
import 'dart:ui' as ui; // For platformViewRegistry
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // For fullscreen functionality
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js; // For JavaScript interop

/// The main entry point of the application.
void main() {
  // Inject JavaScript code to handle fullscreen toggling
  js.context.callMethod('eval', [
    '''
    function toggleFullscreen(imgElement) {
      if (document.fullscreenElement === null) {
        imgElement.requestFullscreen();
      } else {
        document.exitFullscreen();
      }
    }
    '''
  ]);

  // Register the view factory for the HTML <img> element
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(
    'image-view',
    (int viewId) {
      // Create an HTML image element
      final imgElement = html.ImageElement()
        ..id = 'fullscreen-image'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain'
        ..src = '';

      // Attach a double-click event listener to the image
      imgElement.addEventListener('dblclick', (event) {
        // Call the JavaScript function to toggle fullscreen
        js.context.callMethod('toggleFullscreen', [imgElement]);
      });

      return imgElement;
    },
  );

  // Run the application
  runApp(const MyApp());
}

/// The root widget of the application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Web Image Viewer',
      debugShowCheckedModeBanner: false, // Remove the debug banner
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ImageViewer(),
    );
  }
}

/// A widget that displays an image and allows the user to update the image URL.
class ImageViewer extends StatefulWidget {
  const ImageViewer({super.key});

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  String? _imageUrl;
  bool _isMenuOpen = false;
  final GlobalKey _buttonKey =
      GlobalKey(); // Key to track the button's position
  OverlayEntry? _overlayEntry; // To manage the overlay menu

  @override
  void initState() {
    super.initState();
    // Set the default image URL
    _imageUrl = '';
    // Add observer to listen for layout changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remove observer when the widget is disposed
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Called when the app's dimensions change (e.g., browser resize)
    if (_isMenuOpen) {
      _updateMenuPosition();
    }
  }

  /// Updates the displayed image with the URL entered by the user.
  void _updateImage() {
    setState(() {
      _imageUrl = _controller.text.trim();
      // Update the src of the HTML img element
      final imgElement = html.document.getElementById('fullscreen-image')
          as html.ImageElement?;
      if (imgElement != null) {
        imgElement.src = _imageUrl!;
      }
    });
  }

  /// Toggles the visibility of the context menu.
  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _showMenu(context);
      } else {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  /// Toggles fullscreen mode for the entire page.
  void _togglePageFullscreen(bool enterFullscreen) {
    final element = html.document.documentElement;
    if (element != null) {
      if (enterFullscreen) {
        // Enter fullscreen mode for the entire page
        element.requestFullscreen();
      } else {
        // Exit fullscreen mode
        html.document.exitFullscreen();
      }
    }
    _toggleMenu(); // Close the menu after selection
  }

  /// Displays the context menu above the button.
  void _showMenu(BuildContext context) {
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return _buildMenu(context);
      },
    );

    // Insert the overlay into the overlay state
    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Updates the menu's position when the layout changes.
  void _updateMenuPosition() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  /// Builds the menu with the correct position.
  Widget _buildMenu(BuildContext context) {
    final RenderBox buttonRenderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final Offset buttonPosition = buttonRenderBox.localToGlobal(Offset.zero);

    const double menuWidth = 200; // Adjust based on your menu width
    const double menuHeight = 100; // Adjust based on your menu height

    // Calculate the left position to ensure the menu doesn't overflow
    double leftPosition =
        buttonPosition.dx - menuWidth / 2 + 28; // Center the menu
    final double screenWidth = MediaQuery.of(context).size.width;
    if (leftPosition + menuWidth > screenWidth) {
      leftPosition = screenWidth - menuWidth;
    } else if (leftPosition < 0) {
      leftPosition = 0;
    }

    return Stack(
      children: [
        // Darkened background overlay
        GestureDetector(
          onTap: _toggleMenu, // Close the menu when tapping outside
          child: Container(
            color: Colors.black.withOpacity(0.5),
          ),
        ),
        // Menu positioned above the button
        Positioned(
          left: leftPosition,
          top: buttonPosition.dy -
              menuHeight +
              20, // Adjusted to be closer to the button
          child: Material(
            color: Colors.transparent,
            child: Card(
              elevation: 4,
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      _togglePageFullscreen(true);
                    },
                    child: const Text('Enter Fullscreen (Page)'),
                  ),
                  TextButton(
                    onPressed: () {
                      _togglePageFullscreen(false);
                    },
                    child: const Text('Exit Fullscreen (Page)'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Web Image Viewer')),
      body: Stack(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Image Display Container
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300], // Grey background
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _imageUrl != null && _imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: const HtmlElementView(
                              viewType: 'image-view',
                            ),
                          )
                        : const Center(
                            child: Text('Enter an image URL to display'),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                // URL Input and Button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Enter Image URL',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _updateImage,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: const CircleBorder(),
                      ),
                      child: const Icon(Icons.arrow_forward),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Plus button
          Positioned(
            bottom: 80, // Adjusted to avoid overlapping with the input button
            right: 16,
            child: FloatingActionButton(
              key: _buttonKey, // Track the button's position
              onPressed: _toggleMenu,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}
