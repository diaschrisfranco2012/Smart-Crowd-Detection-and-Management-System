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

  // IMPORTANT: Match these to your specific model's training requirements
  static const int inputSize = 224;
  static const double modelMean = 127.5;
  static const double modelStd = 127.5;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/best_float32.tflite',
      );
      print(
        " TFLite Model Loaded: ${_interpreter!.getInputTensor(0).shape}",
      );
    } catch (e) {
      print(" Failed to load model: $e");
    }
  }

  void startListening() async {
    await loadModel();

    _dbRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data == null ||
          _interpreter == null ||
          _isProcessing)
        return;

      String status = data['status'] ?? "";

      // We Grabbing the Cloudinary URL from Firebase
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
        " Downloading image from Cloudinary...",
      );

      // 1. Download Image directly from Cloudinary URL
      final response = await http.get(
        Uri.parse(imageUrl),
      );
      if (response.statusCode != 200)
        throw Exception("Image Download Failed");

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

      // Prepare output buffer (Adjust [1, X] based on your model's classes)
      var output = List<double>.filled(
        2,
        0,
      ).reshape([1, 2]);

      // 3. Run Inference
      _interpreter!.run(input, output);

      double fallConfidence =
          output[0][0]; // Assuming index 0 is 'Fall'
      print(
        " AI Analysis - Fall Confidence: ${(fallConfidence * 100).toStringAsFixed(2)}%",
      );

      if (fallConfidence > 0.75) {
        await _dbRef.update({
          'status': "FALL VERIFIED",
        });
        await NotificationService()
            .showEmergencyAlert();
      } else {
        await _dbRef.update({'status': "Normal"});
      }
    } catch (e) {
      print(" TFLite Processing Error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // Optimized pixel extraction for Float32
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
        buffer[pixelIndex++] =
            (pixel.r - modelMean) / modelStd;
        buffer[pixelIndex++] =
            (pixel.g - modelMean) / modelStd;
        buffer[pixelIndex++] =
            (pixel.b - modelMean) / modelStd;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }
}
