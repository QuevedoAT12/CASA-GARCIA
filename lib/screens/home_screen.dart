import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'fuel_records_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class Ticket {
  final String id;
  final String dateString;
  final Timestamp dateTimestamp;
  final double liters;
  final double amount;
  final String status;

  Ticket({
    required this.id,
    required this.dateString,
    required this.dateTimestamp,
    required this.liters,
    required this.amount,
    required this.status,
  });

  factory Ticket.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Ticket(
      id: doc.id,
      dateString: data['dateString'] ?? 'Fecha no disponible',
      dateTimestamp: data['dateTimestamp'] ?? Timestamp.now(),
      liters: (data['liters'] ?? 0.0).toDouble(),
      amount: (data['amount'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'Pendiente',
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  static const Color azulPrincipalApp = Color(0xFF194F91);
  static const Color azulClaroApp = Color(0xFF477BBF);

  static const Color azulGrisAccion = Color(0xFF607D8B);
  static const Color colorTextoPrincipal = Colors.black87;
  static const Color colorTextoSecundario = Colors.black54;
  static const Color colorFondoScaffold = Color(0xFFF4F6F8);
  static const Color colorVerdeAprobado = Colors.green;
  static const Color colorRojoRechazado = Colors.red;
  static const Color colorGrisDesconocido = Colors.grey;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<Ticket>>? _recentTicketsFuture;
  User? _currentUserForTickets;

  @override
  void initState() {
    super.initState();
    _currentUserForTickets = FirebaseAuth.instance.currentUser;
    if (_currentUserForTickets != null) {
      _refreshTickets();
    } else {
      print("HomeScreen initState: ¡ERROR CRÍTICO! Usuario es null.");
    }
  }

  Future<List<Ticket>> _fetchRecentTickets(User? user) async {
    if (user == null) return [];
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('tickets')
          .where('userId', isEqualTo: user.uid)
          .orderBy('dateTimestamp', descending: true)
          .limit(5)
          .get();
      return querySnapshot.docs.map((doc) => Ticket.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error al cargar tickets recientes para ${user.uid}: $e");
      if (e is FirebaseException && e.code == 'failed-precondition') {
        print("Sugerencia de índice: ${e.message}");
      }
      return [];
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'aprobado':
        return HomeScreen.colorVerdeAprobado;
      case 'pendiente':
        return HomeScreen.azulClaroApp;
      case 'rechazado':
        return HomeScreen.colorRojoRechazado;
      default:
        return HomeScreen.colorGrisDesconocido;
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print("HomeScreen: Error al cerrar sesión: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: ${e.toString()}')),
        );
      }
    }
  }

  void _refreshTickets() {
    if (_currentUserForTickets != null) {
      if (mounted) {
        setState(() {
          _recentTicketsFuture = _fetchRecentTickets(_currentUserForTickets);
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _recentTicketsFuture = Future.value([]);
        });
      }
    }
  }

  void _goToCaptureTicket(BuildContext context) {
    Navigator.pushNamed(context, '/capture-ticket').then((_) {
      if (_currentUserForTickets != null && mounted) _refreshTickets();
    });
  }

  void _goToMyTickets(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FuelRecordsScreen()),
    ).then((_) {
      if (_currentUserForTickets != null && mounted) _refreshTickets();
    });
  }

  void _goToNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
  }

  void _goToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = _currentUserForTickets;

    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: HomeScreen.azulPrincipalApp),
              SizedBox(height: 10),
              Text("Error: No se encontró usuario. Redirigiendo..."),
            ],
          ),
        ),
      );
    }

    final String userName = currentUser.displayName ?? currentUser.email ?? "Usuario";
    final String userEmail = currentUser.email ?? "email@example.com";

    return Scaffold(
      backgroundColor: HomeScreen.colorFondoScaffold,
      appBar: AppBar(
        title: Text(
          '¡Hola ${userName}!',
          style: const TextStyle(
            color: HomeScreen.azulPrincipalApp,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 1,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: HomeScreen.azulPrincipalApp),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, size: 28),
            onPressed: () => _goToNotifications(context),
            tooltip: 'Notificaciones',
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildAppDrawer(context, userName, userEmail),
      body: RefreshIndicator(
        onRefresh: () async => _refreshTickets(),
        color: HomeScreen.azulPrincipalApp,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola ${userName},',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: HomeScreen.colorTextoPrincipal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bienvenido a Casa García',
                style: TextStyle(
                  fontSize: 18,
                  color: HomeScreen.colorTextoSecundario,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Acciones Rápidas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: HomeScreen.colorTextoPrincipal,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context: context,
                      title: 'Capturar Ticket',
                      icon: Icons.camera_alt_outlined,
                      color: HomeScreen.azulPrincipalApp,
                      onTap: () => _goToCaptureTicket(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      context: context,
                      title: 'Ver mis tickets',
                      icon: Icons.receipt_long_outlined,
                      color: HomeScreen.azulGrisAccion,
                      onTap: () => _goToMyTickets(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                'Actividad Reciente',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: HomeScreen.colorTextoPrincipal,
                ),
              ),
              const SizedBox(height: 16),
              if (_recentTicketsFuture == null)
                Center(child: CircularProgressIndicator(color: HomeScreen.azulPrincipalApp))
              else
                FutureBuilder<List<Ticket>>(
                  future: _recentTicketsFuture,
                  builder: (context, snapshotTickets) {
                    if (snapshotTickets.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: HomeScreen.azulPrincipalApp));
                    }
                    if (snapshotTickets.hasError) {
                      return Center(
                        child: Text(
                          'Error al cargar los tickets.\nIntenta refrescar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: HomeScreen.colorTextoSecundario),
                        ),
                      );
                    }
                    if (!snapshotTickets.hasData || snapshotTickets.data!.isEmpty) {
                      return Center(
                        child: Text(
                          'No hay actividad reciente.',
                          style: TextStyle(color: HomeScreen.colorTextoSecundario, fontSize: 16),
                        ),
                      );
                    }

                    final tickets = snapshotTickets.data!;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tickets.length,
                      itemBuilder: (context, index) {
                        final ticket = tickets[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildRecentTicketCard(
                            context,
                            date: ticket.dateString,
                            liters: '${ticket.liters.toStringAsFixed(2)} L',
                            amount: '\$${ticket.amount.toStringAsFixed(2)}',
                            status: ticket.status,
                            statusColor: _getStatusColor(ticket.status),
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTicketCard(
      BuildContext context, {
        required String date,
        required String liters,
        required String amount,
        required String status,
        required Color statusColor,
      }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fecha: $date',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: HomeScreen.colorTextoPrincipal),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(color: Colors.grey.shade300, height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Litros:',
                        style: TextStyle(
                            fontSize: 13,
                            color: HomeScreen.colorTextoSecundario)),
                    const SizedBox(height: 2),
                    Text(liters,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: HomeScreen.colorTextoPrincipal)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Monto:',
                        style: TextStyle(
                            fontSize: 13,
                            color: HomeScreen.colorTextoSecundario)),
                    const SizedBox(height: 2),
                    Text(amount,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: HomeScreen.colorTextoPrincipal)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppDrawer(
      BuildContext context, String userName, String userEmail) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text(
              userName,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white),
            ),
            accountEmail: Text(
              userEmail,
              style: const TextStyle(color: Colors.white70),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : "U",
                style: const TextStyle(
                    fontSize: 40.0, color: HomeScreen.azulPrincipalApp),
              ),
            ),
            decoration: const BoxDecoration(
              color: HomeScreen.azulPrincipalApp,
            ),
          ),
          _buildDrawerItem(
            icon: Icons.receipt_long_outlined,
            text: 'Mis Tickets',
            onTap: () {
              Navigator.pop(context);
              _goToMyTickets(context);
            },
          ),
          _buildDrawerItem(
            icon: Icons.notifications_none_outlined,
            text: 'Notificaciones',
            onTap: () {
              Navigator.pop(context);
              _goToNotifications(context);
            },
          ),
          _buildDrawerItem(
            icon: Icons.settings_outlined,
            text: 'Configuración',
            onTap: () {
              Navigator.pop(context);
              _goToSettings(context);
            },
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.logout_outlined,
            text: 'Cerrar Sesión',
            onTap: () async {
              Navigator.pop(context);
              await _logout(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    required GestureTapCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: HomeScreen.azulPrincipalApp.withOpacity(0.8)),
      title: Text(text,
          style: TextStyle(
              color: HomeScreen.colorTextoPrincipal.withOpacity(0.9),
              fontSize: 15)),
      onTap: onTap,
      dense: true,
    );
  }
}