import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'ticket_validation_screen.dart';

class TicketCaptureScreen extends StatefulWidget {
  const TicketCaptureScreen({Key? key}) : super(key: key);

  @override
  State<TicketCaptureScreen> createState() => _TicketCaptureScreenState();
}

class _TicketCaptureScreenState extends State<TicketCaptureScreen> {
  static const Color azulPrincipalApp = Color(0xFF194F91);
  static const Color azulClaroApp = Color(0xFF477BBF);

  static const Color azulGrisAccion = Color(0xFF607D8B);
  static const Color colorTextoPrincipal = Colors.black87;
  static const Color colorTextoSecundario = Colors.black54;
  static const Color colorFondoScaffold = Color(0xFFF4F6F8);
  static Color colorBordeDiagrama = azulPrincipalApp.withOpacity(0.4);
  static const Color colorTextoPlaceholderTip = Colors.black54;
  static const Color colorPlaceholder = Colors.grey;
  static const Color colorTextoBotones = Colors.white;

  File? _selectedImageFile;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImageAndProceed(ImageSource source) async {
    setState(() {
      _isLoading = true;
      _selectedImageFile = null;
    });

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se seleccionó ninguna imagen.')),
          );
        }
      }
    } catch (e) {
      print("Error al seleccionar imagen: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar imagen: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToValidationScreen() {
    if (_selectedImageFile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TicketValidationScreen(imageFile: _selectedImageFile!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor, selecciona o captura una imagen primero.'),
          backgroundColor: azulClaroApp.withOpacity(0.8),
        ),
      );
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: azulPrincipalApp),
                title: const Text('Seleccionar de la Galería', style: TextStyle(color: colorTextoPrincipal)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImageAndProceed(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: azulPrincipalApp),
                title: const Text('Tomar Foto con la Cámara', style: TextStyle(color: colorTextoPrincipal)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImageAndProceed(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showImageTipsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: azulPrincipalApp),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Consejos para la Foto'),
              ),
            ],
          ),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _TipItem(icon: Icons.wb_sunny_outlined, text: 'Buena Iluminación: Evita sombras y reflejos.'),
                _TipItem(icon: Icons.center_focus_strong_outlined, text: 'Enfoque Claro: Texto nítido, no borroso.'),
                _TipItem(icon: Icons.fullscreen_outlined, text: 'Ticket Completo: Sin cortar bordes.'),
                _TipItem(icon: Icons.straighten_outlined, text: 'Ticket Plano: Colócalo lo más plano posible.'),
                _TipItem(icon: Icons.zoom_out_map_outlined, text: 'Ticket Cerca: Que ocupe la mayor parte.'),
                _TipItem(icon: Icons.no_flash_outlined, text: 'Evita el Flash Directo: Puede causar brillos.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Entendido', style: TextStyle(color: azulPrincipalApp)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondoScaffold,
      appBar: AppBar(
        title: const Text('Capturar Ticket'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: azulPrincipalApp),
            tooltip: 'Consejos para la foto',
            onPressed: () => _showImageTipsDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    )
                  ]),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: azulPrincipalApp))
                  : _selectedImageFile != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(
                  _selectedImageFile!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildImageErrorPlaceholder('Error al cargar imagen'),
                ),
              )
                  : _buildSimplifiedPlaceholderWithDiagram(),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _showImageSourceActionSheet(context),
              icon: const Icon(Icons.camera_alt_outlined, size: 22),
              label: Text(_selectedImageFile == null ? 'Seleccionar / Tomar Foto' : 'Cambiar Imagen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: azulPrincipalApp,
                disabledBackgroundColor: azulPrincipalApp.withOpacity(0.5),
                foregroundColor: colorTextoBotones,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: (_selectedImageFile != null && !_isLoading) ? _navigateToValidationScreen : null,
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
              label: const Text('Continuar y Validar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: azulGrisAccion,
                disabledBackgroundColor: azulGrisAccion.withOpacity(0.5),
                foregroundColor: colorTextoBotones,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageErrorPlaceholder(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined, size: 40, color: colorPlaceholder.withOpacity(0.6)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorPlaceholder.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimplifiedPlaceholderWithDiagram() {
    return InkWell(
      onTap: () => _showImageSourceActionSheet(context),
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: _TicketCaptureScreenState.colorBordeDiagrama, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 130,
                    decoration: BoxDecoration(
                      color: azulPrincipalApp.withOpacity(0.08),
                      border: Border.all(color: azulPrincipalApp.withOpacity(0.5), width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: azulPrincipalApp.withOpacity(0.7), size: 28),
                        SizedBox(height: 4),
                        Text(
                          "Ticket Centrado\ny Completo",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            color: azulPrincipalApp.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _PlaceholderTip(
                      icon: Icons.wb_sunny_outlined,
                      text: "Buena Luz",
                      iconColor: Colors.orange.shade600,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _PlaceholderTip(
                      icon: Icons.center_focus_strong_outlined,
                      text: "Enfocado",
                      iconColor: azulPrincipalApp,
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    child: _PlaceholderTip(
                      icon: Icons.fullscreen_exit_outlined,
                      text: "No cortar bordes",
                      iconColor: Colors.red.shade400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Toca para seleccionar o tomar una foto',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: colorTextoPrincipal.withOpacity(0.8), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: Icon(Icons.info_outline_rounded, color: azulGrisAccion.withOpacity(0.9), size: 18),
              label: Text(
                'Ver todos los consejos',
                style: TextStyle(color: azulGrisAccion, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              onPressed: () => _showImageTipsDialog(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TipItem({Key? key, required this.icon, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20.0, color: _TicketCaptureScreenState.azulPrincipalApp.withOpacity(0.9)),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14.5, color: _TicketCaptureScreenState.colorTextoPrincipal.withOpacity(0.9)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderTip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;

  const _PlaceholderTip({
    Key? key,
    required this.icon,
    required this.text,
    required this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 3,
              offset: Offset(0,1),
            )
          ]
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
                fontSize: 10,
                color: _TicketCaptureScreenState.colorTextoPlaceholderTip,
                fontWeight: FontWeight.w500
            ),
          ),
        ],
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Casa García - Capturar Ticket',
      theme: ThemeData(
          primaryColor: _TicketCaptureScreenState.azulPrincipalApp,
          scaffoldBackgroundColor: _TicketCaptureScreenState.colorFondoScaffold,
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: _TicketCaptureScreenState.azulPrincipalApp,
            secondary: _TicketCaptureScreenState.azulGrisAccion,
            onPrimary: _TicketCaptureScreenState.colorTextoBotones,
            onSecondary: _TicketCaptureScreenState.colorTextoBotones,
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: const AppBarTheme(
            elevation: 1,
            backgroundColor: Colors.white,
            iconTheme: IconThemeData(color: _TicketCaptureScreenState.azulPrincipalApp),
            titleTextStyle: TextStyle(
              color: _TicketCaptureScreenState.azulPrincipalApp,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
              )
          )
      ),
      home: const TicketCaptureScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}