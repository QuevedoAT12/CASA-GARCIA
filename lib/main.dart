import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'dart:io';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/ticket_capture_screen.dart';
import 'screens/ticket_validation_screen.dart';
import 'screens/ticket_confirmation_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/settings_screen.dart';

import 'providers/notification_provider.dart';

const Color azulPrincipal = Color(0xFF194F91);
const Color azulGrisAccion = Color(0xFF607D8B);
const Color colorTextoBotones = Colors.white;
const Color colorFondoScaffold = Color(0xFFF4F6F8);
const Color colorTextoPrincipalTema = Colors.black87;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('es_MX', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'OCR - Casa García',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: azulPrincipal,
          scaffoldBackgroundColor: colorFondoScaffold,
          colorScheme: ColorScheme.fromSeed(
            seedColor: azulPrincipal,
            primary: azulPrincipal,
            secondary: azulGrisAccion,
            onPrimary: Colors.white,
            onSecondary: colorTextoBotones,
            surface: Colors.white,
            onSurface: colorTextoPrincipalTema,
            background: colorFondoScaffold,
            onBackground: colorTextoPrincipalTema,
            error: Colors.red.shade700,
            onError: Colors.white,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            elevation: 1,
            backgroundColor: azulPrincipal,
            foregroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto',
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: azulPrincipal,
              foregroundColor: colorTextoBotones,
              disabledBackgroundColor: azulPrincipal.withOpacity(0.4),
              disabledForegroundColor: colorTextoBotones.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              elevation: 2,
            ),
          ),
          textTheme: const TextTheme(
          ).apply(
            bodyColor: colorTextoPrincipalTema,
            displayColor: colorTextoPrincipalTema,
          ),
        ),
        home: const AuthWrapper(),
        onGenerateRoute: (settings) {
          print(
              "Navegando a la ruta: ${settings.name} con argumentos: ${settings.arguments}");
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(builder: (_) => const AuthWrapper());
            case '/home':
              return MaterialPageRoute(builder: (_) => const HomeScreen());
            case '/capture-ticket':
              return MaterialPageRoute(
                  builder: (_) => const TicketCaptureScreen());
            case '/validate-ticket':
              {
                final args = settings.arguments;
                if (args is Map<String, dynamic> &&
                    args['imageFile'] is File) {
                  final imageFile = args['imageFile'] as File;
                  return MaterialPageRoute(
                    builder: (_) =>
                        TicketValidationScreen(imageFile: imageFile),
                  );
                }
                print(
                    "Error: Argumentos incorrectos para /validate-ticket. Redirigiendo a Login.");
                return MaterialPageRoute(builder: (_) => const LoginScreen());
              }
            case '/confirmation-ticket':
              return MaterialPageRoute(
                  builder: (_) => const TicketConfirmationScreen());
            case '/notifications':
              return MaterialPageRoute(builder: (_) => const NotificationsScreen());
            case '/settings':
              return MaterialPageRoute(builder: (_) => const SettingsScreen());
            default:
              print(
                  'Advertencia: Ruta no encontrada en onGenerateRoute: ${settings.name}. Mostrando LoginScreen o HomeScreen según lógica.');
              return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print("AuthWrapper: Esperando estado de autenticación...");
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: azulPrincipal)),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          print(
              "AuthWrapper: Usuario autenticado (UID: ${snapshot.data!.uid}). Mostrando HomeScreen.");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

            if (!notificationProvider.notifications.any((n) => n.title.contains('Bienvenido'))) {
              notificationProvider.addNotification(
                  '¡Sesión Iniciada!',
                  'Bienvenido/a de nuevo a Casa García.',
                  notificationType: 'auth_login'
              );
            }
          });
          return const HomeScreen();
        }

        print("AuthWrapper: Usuario no autenticado. Mostrando LoginScreen.");
        return const LoginScreen();
      },
    );
  }
}