// lib/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../models/app_notification.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  static const Color azulPrincipalApp = Color(0xFF194F91);
  static const Color azulClaroApp = Color(0xFF477BBF);

  static const Color azulGrisAccion = Color(0xFF607D8B);
  static const Color colorTextoPrincipal = Colors.black87;
  static const Color colorTextoSecundario = Colors.black54;
  static const Color colorFondoScaffold = Color(0xFFF4F6F8);

  static const Color colorTextoLeido = Colors.black54;
  static const Color colorTextoNoLeido = Colors.black87;
  static const Color colorIconoLeido = Colors.grey;
  static const Color colorIconoNoLeido = azulPrincipalApp;

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final notifications = notificationProvider.notifications;

    final appBarTitleColor = Theme.of(context).appBarTheme.titleTextStyle?.color ?? azulPrincipalApp;

    return Scaffold(
      backgroundColor: colorFondoScaffold,
      appBar: AppBar(
        title: Text(
          'Notificaciones',
        ),
        actions: [
          if (notifications.isNotEmpty && notificationProvider.unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: () {
                  notificationProvider.markAllAsRead();
                },
                child: Text(
                  'Marcar Leídas',
                  style: TextStyle(color: appBarTitleColor),
                ),
              ),
            ),
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Borrar todas',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirmar Borrado'),
                    content: const Text('¿Estás seguro de que deseas borrar todas las notificaciones? Esta acción no se puede deshacer.'),
                    actions: <Widget>[
                      TextButton(
                        child: Text('Cancelar', style: TextStyle(color: azulGrisAccion)),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                        },
                      ),
                      TextButton(
                        child: Text('Borrar', style: TextStyle(color: Colors.red.shade700)),
                        onPressed: () {
                          notificationProvider.clearAllNotifications();
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.notifications_off_outlined,
                size: 80,
                color: colorTextoSecundario.withOpacity(0.5),
              ),
              const SizedBox(height: 20),
              const Text(
                'No hay notificaciones nuevas',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: colorTextoPrincipal,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Aquí se mostrarán tus alertas y actualizaciones importantes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: colorTextoSecundario,
                ),
              ),
            ],
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: notifications.length,
        itemBuilder: (ctx, index) {
          final notification = notifications[index];
          return Dismissible(
            key: Key(notification.id),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) {
              notificationProvider.removeNotification(notification.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${notification.title} eliminada.'),
                  backgroundColor: azulClaroApp.withOpacity(0.95),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            background: Container(
              color: Colors.redAccent.withOpacity(0.9),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20.0),
              child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
            ),
            child: Card(
              elevation: notification.isRead ? 1.5 : 3.5,
              margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  side: BorderSide(
                    color: notification.isRead ? Colors.grey.shade300 : azulPrincipalApp.withOpacity(0.6),
                    width: notification.isRead ? 0.8 : 1.2,
                  )),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: notification.isRead
                      ? colorIconoLeido.withOpacity(0.1)
                      : colorIconoNoLeido.withOpacity(0.15),
                  child: Icon(
                    notification.isRead ? Icons.mark_email_read_outlined : Icons.notification_important_rounded,
                    color: notification.isRead ? colorIconoLeido : colorIconoNoLeido,
                    size: 26,
                  ),
                ),
                title: Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                    color: notification.isRead ? colorTextoLeido : colorTextoNoLeido,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: notification.isRead ? colorTextoLeido.withOpacity(0.9) : colorTextoSecundario,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${notification.timestamp.day.toString().padLeft(2, '0')}/${notification.timestamp.month.toString().padLeft(2, '0')}/${notification.timestamp.year}  ${notification.timestamp.hour.toString().padLeft(2, '0')}:${notification.timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                trailing: notification.isRead
                    ? null
                    : Icon(Icons.circle, size: 10, color: azulClaroApp.withOpacity(0.8)),
                isThreeLine: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                onTap: () {
                  if (!notification.isRead) {
                    notificationProvider.markAsRead(notification.id);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}