import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../services/settings_service.dart';

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];
  final SettingsService _settingsService = SettingsService();

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> addNotification(String title, String message, {String? notificationType}) async {
    bool appNotificationsEnabled = await _settingsService.getAppNotificationsEnabled();
    if (!appNotificationsEnabled) {
      if (kDebugMode) {
        print('Notificaciones de la app están deshabilitadas. No se añade: $title');
      }
      return;
    }

    final newNotification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      timestamp: DateTime.now(),
    );
    _notifications.insert(0, newNotification);
    notifyListeners();
    if (kDebugMode) {
      print('Notificación añadida: $title');
    }
  }

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    bool changed = false;
    for (var notification in _notifications) {
      if (!notification.isRead) {
        notification.isRead = true;
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  void clearAllNotifications() {
    if (_notifications.isNotEmpty) {
      _notifications.clear();
      notifyListeners();
    }
  }

  void simulateTicketValidatedNotification(String ticketId) {
    addNotification(
      'Ticket Validado',
      '¡Buenas noticias! Tu ticket $ticketId ha sido validado exitosamente.',
      notificationType: 'ticket_update',
    );
  }

  void simulateWelcomeNotification() {
    addNotification(
      '¡Bienvenido/a a Casa García!',
      'Gracias por unirte. Explora nuestras ofertas y funcionalidades.',
      notificationType: 'welcome',
    );
  }
}