// lib/services/ocr_service.dart
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  final textRecognizer = TextRecognizer();

  Future<String> extractTextFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText =
    await textRecognizer.processImage(inputImage);

    return recognizedText.text;
  }

  void dispose() {
    textRecognizer.close();
  }
}
