import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../payment/bank_book.dart';
import 'backup_logo_asset.dart';

/// A strictly additive VietQR plan. It never edits an existing account,
/// replaces an existing logo path or changes a configured default account.
class VietQrMergePlan {
  const VietQrMergePlan._({
    required this.book,
    required this.accountsToAdd,
    required this.logoSlotsToAdd,
  });

  final BankBook book;
  final int accountsToAdd;
  final List<String> logoSlotsToAdd;

  bool get hasChanges => accountsToAdd > 0 || logoSlotsToAdd.isNotEmpty;

  static String _identity(SavedBankAccount account) =>
      '${account.account.bankBin}:${account.account.accountNumber}';

  static VietQrMergePlan compare({
    required BankBook device,
    required BankBook archive,
    required List<BackupLogoAsset> logos,
  }) {
    device.validate();
    archive.validate();
    final merged = <SavedBankAccount>[...device.accounts];
    final identities = device.accounts.map(_identity).toSet();
    final ids = device.accounts.map((a) => a.id).toSet();
    final addedIds = <String, String>{};
    var count = 0;
    for (final incoming in archive.accounts) {
      final identity = _identity(incoming);
      if (!identities.add(identity)) continue;
      if (merged.length >= 15) {
        throw const FormatException(
          'Đã đạt 15 tài khoản VietQR; không thể nhập bổ sung');
      }
      var id = incoming.id;
      if (ids.contains(id)) {
        final suffix = sha256.convert(utf8.encode(identity)).toString()
            .substring(0, 16);
        id = 'restored_$suffix';
        var counter = 1;
        while (ids.contains(id)) {
          id = 'restored_${suffix}_${counter++}';
        }
      }
      ids.add(id);
      addedIds[incoming.id] = id;
      merged.add(SavedBankAccount(
        id: id, bankName: incoming.bankName, account: incoming.account));
      count++;
    }

    // An unconfigured device may adopt the archived default. Existing
    // accounts/default are never replaced, even when names differ.
    String? selectedId = device.defaultId;
    if (device.accounts.isEmpty && archive.accounts.isNotEmpty) {
      final archivedSelection = archive.selected;
      if (archivedSelection != null) {
        selectedId = addedIds[archivedSelection.id] ??
            merged.where((a) => _identity(a) == _identity(archivedSelection))
              .first.id;
      }
    }

    final slots = <String>[];
    for (final asset in logos) {
      if (asset.slot == 'center' && device.centerLogoPath == null &&
          !slots.contains('center')) {
        slots.add('center');
      }
      if (asset.slot == 'footer' && device.footerLogoPath == null &&
          !slots.contains('footer')) {
        slots.add('footer');
      }
    }
    final result = BankBook(
      accounts: merged,
      defaultId: selectedId,
      centerLogoPath: device.centerLogoPath,
      footerLogoPath: device.footerLogoPath,
    )..validate();
    return VietQrMergePlan._(
      book: result,
      accountsToAdd: count,
      logoSlotsToAdd: List<String>.unmodifiable(slots),
    );
  }
}
