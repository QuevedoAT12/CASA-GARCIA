import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Color azulPrincipalApp = Color(0xFF194F91);
const Color azulClaroApp = Color(0xFF477BBF);

const Color colorTextoPrincipal = Colors.black87;
const Color colorTextoSecundario = Colors.black54;
const Color colorFondoScaffold = Color(0xFFF4F6F8);
const Color colorItemSettingFondo = Colors.white;
const Color colorBotonLogoutFondo = Color(0xFFEEEEEE);
const Color colorBotonLogoutTexto = Colors.black87;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  bool _notificationsEnabled = true;

  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _usernameController.text = _currentUser!.displayName ?? _currentUser!.email ?? 'N/A';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _changeUsername() async {
    if (_currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay usuario autenticado.'), backgroundColor: Colors.red),
      );
      return;
    }

    final TextEditingController newUsernameController = TextEditingController(
        text: _currentUser!.displayName ?? ''
    );

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cambiar nombre de perfil', style: TextStyle(color: azulPrincipalApp)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Ingresa tu nuevo nombre para mostrar (displayName).'),
                const SizedBox(height: 10),
                TextField(
                  controller: newUsernameController,
                  decoration: InputDecoration(
                      hintText: "Nuevo nombre",
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: azulPrincipalApp))
                  ),
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar', style: TextStyle(color: azulClaroApp)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: azulPrincipalApp),
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                final newName = newUsernameController.text.trim();
                if (newName.isNotEmpty) {
                  try {
                    await _currentUser!.updateDisplayName(newName);
                    if (!mounted) return;
                    setState(() {
                      _usernameController.text = newName;
                    });
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: const Text('Nombre de perfil actualizado con éxito.'), backgroundColor: azulClaroApp),
                    );
                  } on FirebaseAuthException catch (e) {
                    if (!mounted) return;
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al actualizar: ${e.message}'), backgroundColor: Colors.red),
                    );
                  }
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('El nombre no puede estar vacío.'), backgroundColor: Colors.orange),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _changePassword() async {
    if (_currentUser == null || _currentUser!.email == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede enviar el correo: usuario o email no disponible.'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: _currentUser!.email!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se ha enviado un correo para restablecer tu contraseña a ${_currentUser!.email}.'),
          duration: const Duration(seconds: 5),
          backgroundColor: azulClaroApp,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar el correo: ${e.message}'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (Route<dynamic> route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String displayUsername = _usernameController.text.isNotEmpty
        ? _usernameController.text
        : (_currentUser?.email ?? 'Usuario');

    return Scaffold(
      backgroundColor: colorFondoScaffold,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: azulPrincipalApp),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Configuración',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: azulPrincipalApp,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle('Cuenta'),
          _buildSettingItem(
            icon: Icons.person_outline,
            title: 'Nombre de perfil',
            subtitle: displayUsername,
            onTap: _changeUsername,
            trailing: _buildEditButton(_changeUsername, "Editar"),
          ),
          const SizedBox(height: 10),
          _buildSettingItem(
            icon: Icons.email_outlined,
            title: 'Correo electrónico',
            subtitle: _currentUser?.email ?? 'No disponible',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('El correo electrónico no se puede cambiar directamente aquí.'),
                  backgroundColor: azulClaroApp,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _buildSettingItem(
            icon: Icons.vpn_key_outlined,
            title: 'Contraseña',
            subtitle: '••••••••',
            onTap: _changePassword,
            trailing: _buildEditButton(_changePassword, "Cambiar"),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Notificaciones'),
          SwitchListTile(
            secondary: Icon(
              Icons.notifications_outlined,
              color: azulClaroApp.withOpacity(0.8),
              size: 26,
            ),
            title: const Text(
              'Activar notificaciones',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorTextoPrincipal,
              ),
            ),
            subtitle: Text(
              _notificationsEnabled ? 'Activadas' : 'Desactivadas',
              style: const TextStyle(
                fontSize: 14,
                color: colorTextoSecundario,
              ),
            ),
            value: _notificationsEnabled,
            onChanged: (bool value) {
              setState(() {
                _notificationsEnabled = value;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Notificaciones ${value ? "activadas" : "desactivadas"}'),
                  backgroundColor: azulClaroApp,
                ),
              );
            },
            activeColor: azulPrincipalApp,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            tileColor: colorItemSettingFondo,
          ),
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorBotonLogoutFondo,
                foregroundColor: colorBotonLogoutTexto,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Cerrar sesión',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 10.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: azulPrincipalApp,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      color: colorItemSettingFondo,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          size: 26,
          color: azulClaroApp.withOpacity(0.8),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: colorTextoPrincipal,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: colorTextoSecundario,
          ),
        ),
        trailing: trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      ),
    );
  }

  Widget _buildEditButton(VoidCallback onPressed, String text) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: azulPrincipalApp,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: azulPrincipalApp.withOpacity(0.3)),
        ),
        elevation: 0,
      ),
      child: Text(text),
    );
  }
}