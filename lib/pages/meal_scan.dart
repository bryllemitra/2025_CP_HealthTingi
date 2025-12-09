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
      _interpreter = await tfl.Interpreter.fromAsset('assets/models/efficientnet_multilabel_real40.tflite');
      
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
      debugPrint('=== Model Details ===');
      debugPrint('Model loaded successfully');
      debugPrint('Model type: MobileNetV2 with sigmoid output');
      debugPrint('Training configuration:');
      debugPrint('  - Image size: 224x224');
      debugPrint('  - Normalization: /255.0 (values in [0, 1])');
      debugPrint('  - Output: Sigmoid activation (multi-label)');
      debugPrint('  - Threshold used in training: 0.5');
      
      debugPrint('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      debugPrint('Input type: ${_interpreter!.getInputTensor(0).type}');
      debugPrint('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
      debugPrint('Output type: ${_interpreter!.getOutputTensor(0).type}');
      debugPrint('Number of labels: ${_labels.length}');

      // Print all labels for debugging
      debugPrint('Labels loaded:');
      for (int i = 0; i < _labels.length; i++) {
        debugPrint('  $i: ${_labels[i]}');
      }

      setState(() {
        _recognitions = _labels
            .map((label) => {'label': label, 'confidence': 0.0})
            .toList();
      });

      // Print detailed model input/output info
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
    } catch (e) {
      debugPrint('Failed to load model: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load AI model: ${e.toString()}', style: const TextStyle(fontFamily: 'Poppins'))),
        );
      }
    }
    setState(() => _isModelLoading = false); 
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
          SnackBar(content: Text('Failed to initialize camera: ${e.toString()}', style: const TextStyle(fontFamily: 'Poppins'))),
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
          SnackBar(content: Text('Failed to capture image: ${e.toString()}', style: const TextStyle(fontFamily: 'Poppins'))),
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
          SnackBar(content: Text('Failed to pick image: ${e.toString()}', style: const TextStyle(fontFamily: 'Poppins'))),
        );
      }
    }
  }

  Future<void> _runModelOnImage(File imageFile) async {
    if (_isolateInterpreter == null) {
      debugPrint('Isolate interpreter not initialized');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI model not ready. Please try again.', style: TextStyle(fontFamily: 'Poppins'))),
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
      final inputShape = inputTensor.shape; // Should be [1, 224, 224, 3]
      final inputSize = inputShape[1]; // Should be 224
      
      debugPrint('Processing image with input size: $inputSize');
      debugPrint('Model input shape: $inputShape');

      // Validate input size
      if (inputSize != 224) {
        debugPrint('WARNING: Model expects $inputSize but training used 224');
      }

      // Resize to 224x224 to match training
      final resizedImage = img.copyResize(
        image, 
        width: 224,
        height: 224,
        interpolation: img.Interpolation.cubic
      );
      
      // Preprocess with [0,1] normalization (matches Python training)
      final inputBuffer = _preprocessImageForMobileNet(resizedImage);
      
      // Reshape to match model input
      final input = inputBuffer.reshape(inputShape);
      
      // Prepare output
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      debugPrint('Model output shape: $outputShape');
      
      // Create output buffer - shape should be [1, NUM_CLASSES]
      final output = List.filled(
        outputShape.reduce((a, b) => a * b), 
        0.0,
      ).reshape(outputShape);
      
      debugPrint('Running inference...');
      
      try {
        await _isolateInterpreter!.run(input, output);
      } catch (e) {
        debugPrint('Inference execution failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI processing error: ${e.toString()}', style: const TextStyle(fontFamily: 'Poppins'))),
          );
        }
        return;
      }

      debugPrint('Inference completed, processing results...');
      
      // Process sigmoid outputs (multi-label classification)
      final results = _processSigmoidOutput(output);
      setState(() => _recognitions = results);
      
      // Show top results
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
          SnackBar(content: Text('Image processing failed: ${e.toString()}', style: const TextStyle(fontFamily: 'Poppins'))),
        );
      }
    }
  }

  // Preprocessing method that exactly matches Python training
  Float32List _preprocessImageForMobileNet(img.Image image) {
    // MobileNetV2 expects 224x224 RGB with values in [0, 1]
    const int inputSize = 224;
    const int numChannels = 3;
    
    final convertedBytes = Float32List(1 * inputSize * inputSize * numChannels);
    final buffer = Float32List.view(convertedBytes.buffer);
    
    int pixelIndex = 0;
    
    // Convert image to float32 and normalize to [0, 1]
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        // Check if we're within image bounds
        if (x < image.width && y < image.height) {
          final pixel = image.getPixel(x, y);
          
          // MobileNetV2 expects RGB channels with values in [0, 1]
          // This matches Python: img = tf.cast(img, tf.float32) / 255.0
          buffer[pixelIndex++] = pixel.r / 255.0;   // Red
          buffer[pixelIndex++] = pixel.g / 255.0;   // Green  
          buffer[pixelIndex++] = pixel.b / 255.0;   // Blue
        } else {
          // Pad with zeros if needed (shouldn't happen since we resized)
          buffer[pixelIndex++] = 0.0;
          buffer[pixelIndex++] = 0.0;
          buffer[pixelIndex++] = 0.0;
        }
      }
    }
    
    // Debug to verify preprocessing
    final minVal = buffer.reduce((a, b) => a < b ? a : b);
    final maxVal = buffer.reduce((a, b) => a > b ? a : b);
    final meanVal = buffer.reduce((a, b) => a + b) / buffer.length;
    debugPrint('Input buffer stats - Min: $minVal, Max: $maxVal, Mean: $meanVal');
    debugPrint('Expected: Values in [0, 1] range (matching Python training)');
    
    return convertedBytes;
  }

  // Process sigmoid outputs for multi-label classification
  List<dynamic> _processSigmoidOutput(List<dynamic> output) {
    try {
      final results = <Map<String, dynamic>>[];
      
      // Handle different output formats
      List<dynamic> predictions;
      if (output is List && output.isNotEmpty) {
        if (output[0] is List) {
          // Output shape is [1, NUM_CLASSES]
          predictions = output[0] as List<dynamic>;
        } else {
          predictions = output;
        }
      } else {
        throw Exception('Unexpected output format');
      }
      
      debugPrint('Processing ${predictions.length} predictions with ${_labels.length} labels');
      
      // For sigmoid outputs, each value is independent probability
      for (int i = 0; i < predictions.length && i < _labels.length; i++) {
        final confidence = (predictions[i] as num).toDouble();
        
        // MobileNetV2 with sigmoid outputs probabilities in [0, 1]
        // Use threshold to filter (0.3 threshold for mobile, was 0.5 in training)
        if (confidence > 0.3) {
          results.add({
            'label': _labels[i],
            'confidence': confidence,
          });
        }
      }
      
      // Sort by confidence (highest first)
      results.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
      
      // Return top 5 results
      final finalResults = results.take(5).toList();
      
      debugPrint('Returning ${finalResults.length} filtered results');
      return finalResults;
      
    } catch (e) {
      debugPrint('Error processing output: $e');
      // Return empty results on error
      return [];
    }
  }

  // Old method kept for reference but not used (compatible with old model if needed)
  Float32List _imageToByteListFloat32(img.Image image, int inputSize) {
    final convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    final buffer = Float32List.view(convertedBytes.buffer);

    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        final pixel = image.getPixel(j, i);
        
        // Simple normalization to [0, 1] range
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
            fontFamily: 'Exo', // Updated to EXO
            fontSize: 24, // Increased size
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
                                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins'), // Updated to Poppins
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
                        style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Poppins'), // Updated to Poppins
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
                    fontFamily: 'Poppins', // Updated to Poppins
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
        selectedLabelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Poppins'),
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