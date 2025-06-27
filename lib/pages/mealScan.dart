import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../main.dart';
import 'budgetPlan.dart';

class MealScanPage extends StatefulWidget {
  const MealScanPage({super.key});

  @override
  State<MealScanPage> createState() => _MealScanPageState();
}

class _MealScanPageState extends State<MealScanPage> {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;

    _controller = CameraController(camera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller!.initialize();

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller!.takePicture();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Image captured: ${image.path}',
            style: const TextStyle(fontFamily: 'Grandstander'),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFFDDE2C6),
        title: const Text(
          'Ingredient Scanner',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontFamily: 'Grandstander',
          ),
        ),
        centerTitle: true,
        leading: const Icon(Icons.menu, color: Colors.black),
        actions: const [Icon(Icons.info_outline, color: Colors.black)],
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller!);
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _captureImage,
                icon: const Icon(Icons.camera, size: 40, color: Colors.white),
              ),
              const SizedBox(width: 30),
              IconButton(
                onPressed: () {
                  // Future: add image picker here
                },
                icon: const Icon(Icons.image, size: 32, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFFDDE2C6),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        currentIndex: 1,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MyHomePage(title: 'Search Meals')),
              );
              break;
            case 1:
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const BudgetPlanPage()),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.currency_ruble), label: ''),
        ],
      ),
    );
  }
}
