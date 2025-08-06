// screens/ticket_confirmation_screen.dart
import 'package:flutter/material.dart';

const Color azulPrincipalApp = Color(0xFF194F91);
const Color azulClaroApp = Color(0xFF477BBF);

const Color colorTextoBlanco = Colors.white;
const Color colorVerdeExito = Colors.green;

class TicketConfirmationScreen extends StatelessWidget {
  const TicketConfirmationScreen({Key? key}) : super(key: key);

  void _goHome(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  void _captureAnotherTicket(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    Navigator.pushNamed(context, '/capture-ticket');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Confirmación',
          style: TextStyle(color: colorTextoBlanco, fontWeight: FontWeight.bold),
        ),
        backgroundColor: azulPrincipalApp,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Icon(
                Icons.check_circle_outline,
                color: colorVerdeExito,
                size: 100.0,
              ),
              const SizedBox(height: 24.0),
              Text(
                '¡Ticket Guardado!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: azulPrincipalApp,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                'Los datos de tu ticket han sido registrados correctamente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.0,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 40.0),
              ElevatedButton.icon(
                icon: const Icon(Icons.home_outlined, color: colorTextoBlanco),
                label: const Text('Volver al Inicio', style: TextStyle(color: colorTextoBlanco)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: azulClaroApp,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  elevation: 2,
                ),
                onPressed: () => _goHome(context),
              ),
              const SizedBox(height: 16.0),
              OutlinedButton.icon(
                icon: Icon(Icons.camera_alt_outlined, color: azulPrincipalApp),
                label: Text('Capturar Otro Ticket', style: TextStyle(color: azulPrincipalApp)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  side: BorderSide(color: azulPrincipalApp, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                onPressed: () => _captureAnotherTicket(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}