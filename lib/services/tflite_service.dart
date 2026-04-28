import 'dart:typed_data';

import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'notification_service.dart';

class TfLiteService {
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref(
        'crowd_monitor/zone_A',
      );
  Interpreter? _interpreter;
  bool _isProcessing = false;

  // FIXED: Match Ultralytics YOLOv8 Metadata
  static const int inputSize = 640;

  Future<void> loadModel() async {
    try {
      // FIXED: Use Mevin's float16 model
      _interpreter = await Interpreter.fromAsset(
        'assets/best_float16.tflite',
      );
      print(
        "✅ TFLite Model Loaded: ${_interpreter!.getInputTensor(0).shape}",
      );
    } catch (e) {
      print("❌ Failed to load model: $e");
    }
  }

  void startListening() async {
    await loadModel();

    _dbRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data == null ||
          _interpreter == null ||
          _isProcessing) {
        return;
      }
      String status = data['status'] ?? "";

      // We Grab the Cloudinary URL from Firebase
      // Make sure your Python script is saving it to this exact key if you want it here!
      String imageUrl =
          data['latest_evidence_url'] ?? "";

      if (status == "POTENTIAL FALL" &&
          imageUrl.isNotEmpty) {
        _isProcessing = true;
        await _verifyFall(imageUrl);
      }
    });
  }

  Future<void> _verifyFall(
    String imageUrl,
  ) async {
    try {
      print(
        "⬇️ Downloading image from Cloudinary...",
      );

      // 1. Download Image directly from Cloudinary URL
      final response = await http.get(
        Uri.parse(imageUrl),
      );
      if (response.statusCode != 200) {
        throw Exception("Image Download Failed");
      }

      // 2. Decode and Resize using the 'image' package
      img.Image? originalImage = img.decodeImage(
        response.bodyBytes,
      );
      if (originalImage == null) return;

      img.Image resizedImage = img.copyResize(
        originalImage,
        width: inputSize,
        height: inputSize,
      );

      // Convert image to Float32 list for the model
      var input = _imageToByteListFloat32(
        resizedImage,
      );

      // 🛠FIXED: Ultralytics YOLOv8 Detect Output Shape is [1, 6, 8400]
      // 4 Bounding Box coords + 2 Classes (Fall, Not-Fall) = 6
      var output = List<double>.filled(
        1 * 6 * 8400,
        0.0,
      ).reshape([1, 6, 8400]);

      // 3. Run Inference
      print("🧠 Running AI Inference...");
      _interpreter!.run(input, output);

      // 4. Parse YOLO Output to find the highest confidence "Fall"
      double maxFallConfidence = 0.0;

      for (int i = 0; i < 8400; i++) {
        // According to metadata: 0 is 'fall', 1 is 'not-fall'
        // Index 0,1,2,3 are box coords. Index 4 is Class 0 (Fall) confidence.
        double fallConf =
            output[0][4][i] as double;
        if (fallConf > maxFallConfidence) {
          maxFallConfidence = fallConf;
        }
      }

      print(
        "📊 AI Analysis - Max Fall Confidence: ${(maxFallConfidence * 100).toStringAsFixed(2)}%",
      );

      if (maxFallConfidence > 0.75) {
        await _dbRef.update({
          'status': "FALL VERIFIED",
        });

        // FIXED: Added required arguments for the updated NotificationService
        await NotificationService()
            .showEmergencyAlert(
              '🚨 MEDICAL EMERGENCY',
              'AI has verified a fall from the live feed evidence. Immediate assistance required.',
            );
      } else {
        await _dbRef.update({'status': "Normal"});
        print(
          "🛡️ False alarm, fall not verified by AI.",
        );
      }
    } catch (e) {
      print("❌ TFLite Processing Error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // FIXED: Optimized pixel extraction for YOLOv8 (0.0 to 1.0 normalization)
  Uint8List _imageToByteListFloat32(
    img.Image image,
  ) {
    var convertedBytes = Float32List(
      1 * inputSize * inputSize * 3,
    );
    var buffer = Float32List.view(
      convertedBytes.buffer,
    );
    int pixelIndex = 0;

    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        var pixel = image.getPixel(x, y);
        // YOLOv8 just divides by 255.0
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }
}
