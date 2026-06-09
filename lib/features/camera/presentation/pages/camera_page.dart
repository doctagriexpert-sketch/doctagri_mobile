import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/radius.dart';
import '../../../../core/constants/curves.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;
  late List<CameraDescription> _cameras;
  int _cameraIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupCamera().catchError((e) {
      if (kDebugMode) debugPrint('Camera init error: $e');
    });
  }

  Future<void> _setupCamera() async {
    final hasPermission = await _requestCameraPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission caméra requise'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune caméra disponible'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    // Préférence caméra arrière
    _cameraIndex = _cameras.indexWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
    );
    if (_cameraIndex == -1) _cameraIndex = 0;

    _controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    _initFuture = _controller!
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((e) {
          if (kDebugMode) debugPrint('Camera init error: $e');
        });
  }

  Future<bool> _requestCameraPermission() async {
    var status = await Permission.camera.status;

    if (status.isGranted) return true;

    if (status.isDenied) {
      status = await Permission.camera.request();
      return status.isGranted;
    }

    if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.parchment,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
          title: Text(
            'Permission requise',
            style: TextStyle(color: AppColors.bark),
          ),
          content: Text(
            'L\'accès à la caméra est nécessaire pour scanner les plantes.',
            style: TextStyle(color: AppColors.bark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Paramètres'),
            ),
          ],
        ),
      );

      if (shouldOpen == true) {
        await openAppSettings();
      }
      return false;
    }

    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _controller;
    if (cam == null || !cam.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      cam.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera();
    }
  }

  Future<void> _capture() async {
    final cam = _controller;
    if (cam == null || !cam.value.isInitialized) return;

    try {
      final image = await cam.takePicture();
      if (mounted) {
        context.push('/result', extra: image.path);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Capture error: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
      context.push('/result', extra: image.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Centrez la feuille malade',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _controller != null &&
              _controller!.value.isInitialized) {
            return _buildCameraView();
          }

          return const Center(
            child: CircularProgressIndicator(color: AppColors.sage),
          );
        },
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_controller!),

        // Cadre de centrage – couleur sage, pas greenAccent
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.sage, width: 3),
              borderRadius: AppRadius.large,
            ),
          ),
        ),

        // Bouton capture
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 45),
            child: TapAnimation(
              onTap: _capture,
              pressedScale: 0.94,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: AppColors.primary, width: 5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(80),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
            ),
          ),
        ),

        // Bouton galerie
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 130),
            child: TextButton.icon(
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library, color: Colors.white70),
              label: Text(
                'Galerie',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
