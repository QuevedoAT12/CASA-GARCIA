import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isSendingPasswordReset = false;

  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmailAndPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No se encontró un usuario con ese correo electrónico.';
      } else if (e.code == 'wrong-password') {
        message = 'Contraseña incorrecta.';
      } else if (e.code == 'invalid-email') {
        message = 'El formato del correo electrónico no es válido.';
      } else if (e.code == 'network-request-failed') {
        message = 'Error de red. Por favor, verifica tu conexión.';
      } else if (e.code == 'invalid-credential') {
        message = 'Credenciales inválidas. Verifica tu correo y contraseña.';
      } else {
        message = 'Ocurrió un error. Por favor, inténtalo de nuevo.';
        print('Error de Firebase Auth: ${e.message} (code: ${e.code})');
      }
      if (mounted) setState(() => _errorMessage = message);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage =
        'Ocurrió un error inesperado. Por favor, inténtalo de nuevo.');
      }
      print('Error inesperado de login: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToRegisterScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    if (email.isEmpty) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Por favor, ingresa tu correo para restablecer la contraseña.',
            style: TextStyle(color: theme.colorScheme.onErrorContainer),
          ),
          backgroundColor: theme.colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
        .hasMatch(email)) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Por favor, ingresa un correo electrónico válido.',
            style: TextStyle(color: theme.colorScheme.onErrorContainer),
          ),
          backgroundColor: theme.colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSendingPasswordReset = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Correo de restablecimiento enviado a $email.',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No existe una cuenta con ese correo electrónico.';
      } else if (e.code == 'invalid-email') {
        message = 'El formato del correo electrónico no es válido.';
      } else {
        message = 'Error al enviar el correo. Inténtalo de nuevo.';
        print('Error (Password Reset): ${e.message} (code: ${e.code})');
      }
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: TextStyle(color: theme.colorScheme.onError),
            ),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Ocurrió un error inesperado: $e',
              style: TextStyle(color: theme.colorScheme.onError),
            ),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      print('Error inesperado (Password Reset): $e');
    } finally {
      if (mounted) setState(() => _isSendingPasswordReset = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'account-exists-with-different-credential') {
        message =
        'Ya existe una cuenta con este correo y otro método de inicio.';
      } else if (e.code == 'invalid-credential') {
        message = 'Credenciales de Google no válidas.';
      } else if (e.code == 'network-request-failed') {
        message = 'Error de red. Verifica tu conexión.';
      } else {
        message = 'Error con el inicio de sesión de Google.';
        print('Error (Google): ${e.message} (code: ${e.code})');
      }
      if (mounted) setState(() => _errorMessage = message);
    } catch (e) {
      print('Error inesperado (Google Sign-In): $e');
      if (mounted) {
        setState(() => _errorMessage =
        'Error inesperado durante el inicio de sesión con Google.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    final bool isEmailPassLoading = _isLoading &&
        !_isSendingPasswordReset &&
        (_emailController.text.isNotEmpty ||
            _passwordController.text.isNotEmpty);

    final bool isGoogleLoading = _isLoading &&
        !_isSendingPasswordReset &&
        _emailController.text.isEmpty &&
        _passwordController.text.isEmpty;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withOpacity(0.9),
              colorScheme.primary.withOpacity(0.6),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 25.0, top: 20.0),
                    child: CircleAvatar(
                      radius: 85,
                      backgroundColor: colorScheme.surface.withOpacity(0.2),
                      backgroundImage: const AssetImage('assets/images/casagarcia.jpeg'),
                    ),
                  ),
                  Text(
                    'Bienvenido',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inicia sesión para continuar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onPrimary.withOpacity(0.85),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _emailController,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color ?? colorScheme.onSurface),
                    decoration: _inputDecoration(
                        theme: theme,
                        hintText: 'Correo Electrónico',
                        prefixIcon: Icons.email_outlined),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, ingresa tu correo electrónico';
                      }
                      if (!RegExp(
                          r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                          .hasMatch(value)) {
                        return 'Ingresa un correo electrónico válido';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color ?? colorScheme.onSurface),
                    decoration: _inputDecoration(
                      theme: theme,
                      hintText: 'Contraseña',
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: colorScheme.primary,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, ingresa tu contraseña';
                      }
                      if (value.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 10),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: colorScheme.onPrimary.withOpacity(0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _isSendingPasswordReset
                        ? _loadingIndicator(color: colorScheme.onPrimary.withOpacity(0.9), size: 20)
                        : TextButton(
                      onPressed:
                      _isLoading ? null : _sendPasswordResetEmail,
                      style: TextButton.styleFrom(
                          padding:
                          const EdgeInsets.symmetric(vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: colorScheme.onPrimary.withOpacity(0.9)
                      ),
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading || _isSendingPasswordReset
                        ? null
                        : _signInWithEmailAndPassword,
                    child: isEmailPassLoading
                        ? _loadingIndicator(color: colorScheme.onPrimary)
                        : Text(
                      'Iniciar Sesión',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: <Widget>[
                      Expanded(
                          child: Divider(
                              color: colorScheme.onPrimary.withOpacity(0.3),
                              thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Text(
                          'O inicia sesión con',
                          style: TextStyle(
                              color: colorScheme.onPrimary.withOpacity(0.7),
                              fontSize: 13),
                        ),
                      ),
                      Expanded(
                          child: Divider(
                              color: colorScheme.onPrimary.withOpacity(0.3),
                              thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (isGoogleLoading)
                    Center(child: _loadingIndicator(color: colorScheme.onPrimary.withOpacity(0.8), size: 28))
                  else
                    Center(
                      child: _socialButton(
                        context: context,
                        label: "Google",
                        onTap: _isLoading || _isSendingPasswordReset
                            ? null
                            : _signInWithGoogle,
                      ),
                    ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        '¿No tienes una cuenta? ',
                        style: TextStyle(
                            color: colorScheme.onPrimary.withOpacity(0.7),
                            fontSize: 14),
                      ),
                      TextButton(
                        onPressed: _isLoading || _isSendingPasswordReset
                            ? null
                            : _navigateToRegisterScreen,
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: colorScheme.onPrimary
                        ),
                        child: Text(
                          'Regístrate',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                            decorationColor: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required ThemeData theme,
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
      prefixIcon: Icon(prefixIcon, color: theme.colorScheme.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: theme.colorScheme.surface.withOpacity(0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.5), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      ),
      contentPadding:
      const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
    );
  }

  Widget _loadingIndicator(
      {required Color color, double size = 20.0, double strokeWidth = 2.0}) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }

  Widget _socialButton({
    required BuildContext context,
    IconData? iconData,
    String? iconAsset,
    required String label,
    required VoidCallback? onTap,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    Widget iconWidget;

    if (iconData != null) {
      iconWidget = Icon(
        iconData,
        color: onTap == null
            ? colorScheme.onSurface.withOpacity(0.5)
            : Colors.blueAccent,
        size: 24,
      );
    } else if (iconAsset != null) {
      iconWidget = Image.asset(
        iconAsset,
        height: 22,
        width: 22,
      );
    } else {
      iconWidget = Text(label.substring(0,1), style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold));
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: onTap == null
                    ? colorScheme.outline.withOpacity(0.3)
                    : colorScheme.outline,
                width: 1),
            boxShadow: onTap == null
                ? []
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
            ],
          ),
        ),
      ),
    );
  }
}