// Service wrapper around the contacts picker and permission flow.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactDraft {
  const ContactDraft({
    required this.name,
    required this.phoneNumber,
  });

  final String name;
  final String phoneNumber;
}

abstract class ContactImportService {
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Future<void> openSettings();
  Future<ContactDraft?> pickContact();
}

class FlutterContactImportService implements ContactImportService {
  @override
  Future<bool> hasPermission() async {
    final status = await FlutterContacts.permissions.check(PermissionType.readWrite);
    return status == PermissionStatus.granted;
  }

  @override
  Future<bool> requestPermission() async {
    final status = await FlutterContacts.permissions.request(PermissionType.readWrite);
    return status == PermissionStatus.granted;
  }

  @override
  Future<void> openSettings() async {
    await FlutterContacts.permissions.openSettings();
  }

  @override
  Future<ContactDraft?> pickContact() async {
    final contact = await FlutterContacts.native.showPicker(
      properties: {ContactProperty.name, ContactProperty.phone},
    );
    if (contact == null) {
      return null;
    }

    final name = contact.displayName?.trim() ?? '';
    final phone = contact.phones.isNotEmpty
        ? contact.phones.first.number.trim()
        : '';
    return ContactDraft(name: name, phoneNumber: phone);
  }
}

final contactImportServiceProvider = Provider<ContactImportService>((ref) {
  return FlutterContactImportService();
});
