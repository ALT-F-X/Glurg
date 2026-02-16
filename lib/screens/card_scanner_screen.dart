import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/card_name_extractor.dart';
import '../widgets/scanner_overlay.dart';

class CardScannerScreen extends StatefulWidget {
  const CardScannerScreen({super.key});

  @override
  State<CardScannerScreen> createState() => _CardScannerScreenState();
}

class _CardScannerScreenState extends State<CardScannerScreen> {
  CameraController? _cameraController;
  final _textRecognizer = TextRecognizer();
  final _nameExtractor = CardNameExtractor();

  bool _hasPermission = false;
  bool _permissionDenied = false;
  bool _cameraReady = false;
  bool _isProcessing = false;
  String? _detectedName;
  DateTime _lastProcessed = DateTime.now();

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isGranted) {
      setState(() => _hasPermission = true);
      await _initCamera();
    } else {
      setState(() => _permissionDenied = true);
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Use back camera
    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _cameraController!.initialize();
    if (!mounted) return;

    setState(() => _cameraReady = true);

    // Start processing camera frames for OCR
    _cameraController!.startImageStream(_processCameraFrame);
  }

  void _processCameraFrame(CameraImage image) {
    // Throttle: only process every 500ms
    final now = DateTime.now();
    if (now.difference(_lastProcessed).inMilliseconds < 500) return;
    if (_isProcessing) return;
    if (_detectedName != null) return;

    _isProcessing = true;
    _lastProcessed = now;

    _runOcr(image);
  }

  Future<void> _runOcr(CameraImage image) async {
    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final recognizedText = await _textRecognizer.processImage(inputImage);
      if (!mounted) return;

      final cardName = _nameExtractor.extractCardName(recognizedText);

      if (cardName != null && cardName.isNotEmpty) {
        HapticFeedback.lightImpact();
        setState(() => _detectedName = cardName);
        // Stop the image stream once we have a name
        _cameraController?.stopImageStream();
      }
    } catch (e) {
      // OCR processing failed - try again next frame
    } finally {
      _isProcessing = false;
    }
  }

  InputImageRotation _getRotation() {
    final sensorOrientation = _cameraController?.description.sensorOrientation ?? 0;
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    if (image.planes.isEmpty) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _getRotation(),
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _confirmName() {
    if (_detectedName != null) {
      Navigator.pop(context, _detectedName);
    }
  }

  void _tryAgain() {
    setState(() => _detectedName = null);
    // Resume the image stream
    _cameraController?.startImageStream(_processCameraFrame);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return _buildPermissionDenied();
    }

    if (!_hasPermission || !_cameraReady) {
      return _buildLoading();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scan Card'),
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Camera preview (full screen)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),
          // Viewfinder overlay
          const ScannerOverlay(),
          // Detected name panel
          if (_detectedName != null) _buildDetectedPanel(),
        ],
      ),
    );
  }

  Widget _buildDetectedPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Detected Card',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              _detectedName!,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _tryAgain,
                    child: const Text('Try Again'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _confirmName,
                    icon: const Icon(Icons.add),
                    label: Text('Add "$_detectedName"'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Card')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Camera Permission Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Camera access is needed to scan card names. You can still type card names manually.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => openAppSettings(),
                child: const Text('Open Settings'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
