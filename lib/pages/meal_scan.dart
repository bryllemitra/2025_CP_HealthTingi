// Modified meal_scan.dart with UI consistency to login.dart theme
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as img;

import 'home.dart';
import 'budget_plan.dart';
import '../searchMeals/meal_search.dart';
import 'navigation.dart';
import '../ingredientScanner/success.dart';
import 'dart:typed_data';

class MealScanPage extends StatefulWidget {
  final int userId;

  const MealScanPage({super.key, required this.userId});

  @override
  State<MealScanPage> createState() => _MealScanPageState();
}

class _MealScanPageState extends State<MealScanPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture; // Fixed: Changed from late to nullable
  bool _isFlashOn = false;
  bool _showInfo = false;
  List<dynamic> _recognitions = [];
  bool _isModelLoading = false;
  tfl.Interpreter? _interpreter;
  tfl.IsolateInterpreter? _isolateInterpreter; // For async inference
  List<String> _labels = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }

  Future<void> _loadModel() async {
    setState(() => _isModelLoading = true);
    try {
      // Create interpreter from asset - UPDATED MODEL NAME
      _interpreter = await tfl.Interpreter.fromAsset('assets/models/kaggle_single.tflite');
      
      // Create isolate interpreter for async inference (prevents UI blocking)
      _isolateInterpreter = await tfl.IsolateInterpreter.create(
        address: _interpreter!.address,
      );
      
      // Load labels from assets
      final labelFile = await DefaultAssetBundle.of(context)
          .loadString('assets/models/labels.txt');
      _labels = labelFile.split('\n')
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty)
          .toList();

      // Print model info for debugging
      debugPrint('Model loaded successfully');
      debugPrint('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      debugPrint('Input type: ${_interpreter!.getInputTensor(0).type}');
      debugPrint('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
      debugPrint('Output type: ${_interpreter!.getOutputTensor(0).type}');
      debugPrint('Number of labels: ${_labels.length}');

      setState(() {
        _recognitions = _labels
            .map((label) => {'label': label, 'confidence': 0.0})
            .toList();
      });
    } catch (e) {
      debugPrint('Failed to load model: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load AI model: ${e.toString()}')),
        );
      }
    }
    setState(() => _isModelLoading = false); 

    // In _loadModel() after creating interpreter:
    debugPrint('Model input details:');
    for (int i = 0; i < _interpreter!.getInputTensors().length; i++) {
      final tensor = _interpreter!.getInputTensor(i);
      debugPrint('Input $i: shape=${tensor.shape}, type=${tensor.type}');
    }

    debugPrint('Model output details:');
    for (int i = 0; i < _interpreter!.getOutputTensors().length; i++) {
      final tensor = _interpreter!.getOutputTensor(i);
      debugPrint('Output $i: shape=${tensor.shape}, type=${tensor.type}');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }
      
      final camera = cameras.first;

      _controller = CameraController(
        camera,
        ResolutionPreset.high, // Changed to high for better quality
        enableAudio: false,
      );
      
      // Fixed: Initialize the future here instead of using late
      _initializeControllerFuture = _controller!.initialize();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize camera: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _toggleFlash() async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) return;

      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.off : FlashMode.torch,
      );
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      debugPrint('Flash toggle error: $e');
    }
  }

  Future<void> _captureImage() async {
    try {
      // Fixed: Check if controller future is initialized
      if (_initializeControllerFuture == null) {
        throw Exception('Camera not ready');
      }
      
      await _initializeControllerFuture!;
      
      // Ensure camera is ready and focused
      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.setFocusMode(FocusMode.auto);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      final image = await _controller!.takePicture();

      if (!mounted) return;

      // Check image file size (rough quality indicator)
      final file = File(image.path);
      final fileSize = await file.length();
      debugPrint('Captured image size: ${fileSize ~/ 1024} KB');
      
      if (fileSize < 50) { // Less than 50KB might be too low quality
        debugPrint('Warning: Image file size is very small');
      }

      // Show loading indicator while processing
      setState(() => _isModelLoading = true);
      
      await _runModelOnImage(File(image.path));
      
      setState(() => _isModelLoading = false);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScanSuccessPage(
              userId: widget.userId,
              recognitions: _recognitions,
              imagePath: image.path,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
      setState(() => _isModelLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture image: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90, // Increased quality
      );

      if (pickedFile != null && mounted) {
        setState(() => _isModelLoading = true);
        
        await _runModelOnImage(File(pickedFile.path));
        
        setState(() => _isModelLoading = false);

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScanSuccessPage(
                userId: widget.userId,
                recognitions: _recognitions,
                imagePath: pickedFile.path,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Gallery pick error: $e');
      setState(() => _isModelLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _runModelOnImage(File imageFile) async {
    if (_isolateInterpreter == null) {
      debugPrint('Isolate interpreter not initialized');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI model not ready. Please try again.')),
        );
      }
      return;
    }

    try {
      final imageBytes = await imageFile.readAsBytes();
      var image = img.decodeImage(imageBytes);
      
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Get input tensor info
      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape; // This should be [1, 224, 224, 3]
      final inputSize = inputShape[1]; // This should be 224 for your new model
      
      debugPrint('Processing image with input size: $inputSize');
      debugPrint('Model input shape: $inputShape');

      // Validate expected input size - UPDATED FOR 224x224
      if (inputSize != 224) {
        debugPrint('WARNING: Model expects $inputSize but training used 224x224');
      }

      // Preprocess image with better interpolation - MATCHES YOUR TRAINING SIZE
      final resizedImage = img.copyResize(
        image, 
        width: 224,  // FIXED: Hardcoded to match your training size
        height: 224, // FIXED: Hardcoded to match your training size
        interpolation: img.Interpolation.cubic
      );
      
      // CORRECT: Preprocessing that matches your training (simple [0,1] normalization)
      final inputBuffer = _imageToByteListFloat32(resizedImage, 224); // FIXED: Use 224

      // Reshape the 1D buffer to match the model's 4D input shape [1, 224, 224, 3]
      final input = inputBuffer.reshape(inputShape); 

      // Prepare output tensor - get its shape first
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      debugPrint('Model output shape: $outputShape');
      final output = List.filled(
        outputShape.reduce((a, b) => a * b), 
        0.0,
      ).reshape(outputShape); // Reshape the output list as well

      debugPrint('Running inference...');
      
      // Use async inference to prevent UI blocking
      try {
        await _isolateInterpreter!.run(input, output);
      } catch (e) {
        // This catches errors specifically during the inference execution
        debugPrint('Inference execution failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI processing error: ${e.toString()}')),
          );
        }
        return; // Exit the function early since inference failed
      }

      debugPrint('Inference completed, processing results...');

      // Process results
      final results = _processOutput(output);
      setState(() => _recognitions = results);
      
      // Show all 5 top results with confidence percentages
      if (results.isNotEmpty) {
        debugPrint('All ${results.length} results:');
        for (int i = 0; i < results.length; i++) {
          final result = results[i];
          debugPrint('${i + 1}. ${result['label']}: ${(result['confidence'] * 100).toStringAsFixed(2)}%');
        }
      } else {
        debugPrint('No results found');
      }
      
    } catch (e) {
      debugPrint('Error in _runModelOnImage: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image processing failed: ${e.toString()}')),
        );
      }
    }
  }

  // CORRECT: Preprocessing that matches your training (simple [0,1] normalization)
  Float32List _imageToByteListFloat32(img.Image image, int inputSize) {
    final convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    final buffer = Float32List.view(convertedBytes.buffer);

    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        final pixel = image.getPixel(j, i);
        
        // CORRECT: Simple normalization to [0, 1] range - MATCHES YOUR TRAINING
        // Your Python training code: rescale=1./255
        buffer[pixelIndex++] = pixel.r / 255.0;   // Red
        buffer[pixelIndex++] = pixel.g / 255.0;   // Green  
        buffer[pixelIndex++] = pixel.b / 255.0;   // Blue
      }
    }
    
    // Debug statistics to verify preprocessing
    final minVal = buffer.reduce((a, b) => a < b ? a : b);
    final maxVal = buffer.reduce((a, b) => a > b ? a : b);
    final meanVal = buffer.reduce((a, b) => a + b) / buffer.length;
    debugPrint('Input buffer stats - Min: $minVal, Max: $maxVal, Mean: $meanVal');
    debugPrint('Expected range: 0.0 to 1.0 (matching training)');
    
    return convertedBytes;
  }

  List<dynamic> _processOutput(List<dynamic> output) {
    try {
      final results = <Map<String, dynamic>>[];
      
      // Handle different output formats
      List<dynamic> predictions;
      if (output is List && output.isNotEmpty) {
        if (output[0] is List) {
          predictions = output[0] as List<dynamic>;
        } else {
          predictions = output;
        }
      } else {
        throw Exception('Unexpected output format');
      }
      
      debugPrint('Processing ${predictions.length} predictions with ${_labels.length} labels');
      
      for (int i = 0; i < predictions.length && i < _labels.length; i++) {
        final confidence = (predictions[i] as num).toDouble();
        results.add({
          'label': _labels[i],
          'confidence': confidence,
        });
      }
      
      // Sort by confidence in descending order
      results.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
      
      // Filter results with confidence > threshold (adjust as needed)
      final filteredResults = results.where((result) => 
          (result['confidence'] as double) > 0.01).toList(); // Lowered threshold to see more results
      
      // Return top 5 results or all filtered results if less than 5
      final finalResults = filteredResults.take(5).toList();
      
      debugPrint('Returning ${finalResults.length} filtered results');
      return finalResults.isNotEmpty ? finalResults : results.take(5).toList();
      
    } catch (e) {
      debugPrint('Error processing output: $e');
      // Return default results on error
      return _labels.take(5).map((label) => {
        'label': label, 
        'confidence': 0.0
      }).toList();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _interpreter?.close();
    _isolateInterpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: NavigationDrawerWidget(userId: widget.userId),
      backgroundColor: Color(0xFF184E77), // Keep black for camera preview visibility
      appBar: AppBar(
        backgroundColor: const Color(0xFF184E77), // Deep slate blue
        elevation: 10,
        centerTitle: true,
        title: const Text(
          'Scanner',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Orbitron',
            shadows: [
              Shadow(
                color: Colors.black26,
                offset: Offset(2, 2),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {
              setState(() {
                _showInfo = !_showInfo;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                // Fixed: Added null check for _initializeControllerFuture
                child: _initializeControllerFuture == null 
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : FutureBuilder<void>(
                        future: _initializeControllerFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done) {
                            if (_controller != null && _controller!.value.isInitialized) {
                              return CameraPreview(_controller!);
                            } else {
                              return const Center(
                                child: Text(
                                  'Camera not available',
                                  style: TextStyle(color: Colors.white),
                                ),
                              );
                            }
                          } else {
                            return const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            );
                          }
                        },
                      ),
              ),
              if (_isModelLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF76C893)),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Analyzing image...',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: _isModelLoading ? null : _pickImageFromGallery,
                      icon: const Icon(Icons.photo_library, size: 36),
                      color: _isModelLoading ? Colors.grey : Colors.white,
                    ),
                    GestureDetector(
                      onTap: _isModelLoading ? null : _captureImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isModelLoading ? Colors.grey : Colors.white, 
                            width: 5,
                          ),
                        ),
                        child: Icon(
                          Icons.camera,
                          size: 48,
                          color: _isModelLoading ? Colors.grey : Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isModelLoading ? null : _toggleFlash,
                      icon: Icon(
                        _isFlashOn ? Icons.flash_on : Icons.flash_off,
                        size: 36,
                        color: _isModelLoading ? Colors.grey : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_showInfo)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Scan one or more ingredients in a photo. Automatically get names, nutrition facts, and meal suggestions.\n\nTip: Make sure your ingredients are well-lit and clearly visible for best results.',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 14,
                    color: Color(0xFF184E77),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF184E77), // Deep slate blue
        selectedItemColor: Color(0xFF184E77),
        unselectedItemColor: Color(0xFF184E77).withOpacity(0.7),
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(
                    title: 'HealthTingi',
                    userId: widget.userId,
                  ),
                ),
              );
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => MealSearchPage(
                    userId: widget.userId,
                  ),
                ),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => BudgetPlanPage(
                    userId: widget.userId,
                  ),
                ),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Recipes',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.currency_ruble), label: 'Budget'),
        ],
      ),
    );
  }
}