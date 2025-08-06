import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _appNotificationsEnabledKey = 'appNotificationsEnabled';
  static const String _smsMessagesKey = 'smsMessages';
  static const String _emailNotificationsKey = 'emailNotifications';

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  Future<bool> getAppNotificationsEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_appNotificationsEnabledKey) ?? true;
  }

  Future<void> setAppNotificationsEnabled(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_appNotificationsEnabledKey, value);
  }

  Future<bool> getSmsMessagesEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_smsMessagesKey) ?? false;
  }

  Future<void> setSmsMessagesEnabled(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_smsMessagesKey, value);
  }

  Future<bool> getEmailNotificationsEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_emailNotificationsKey) ?? true;
  }

  Future<void> setEmailNotificationsEnabled(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_emailNotificationsKey, value);
  }
}