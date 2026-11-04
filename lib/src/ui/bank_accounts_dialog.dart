import 'package:flutter/material.dart';
import '../payment/bank_book.dart';
import '../payment/bank_catalog.dart';
import '../payment/brand_logo_storage.dart';
import '../payment/vietqr.dart';

class BankAccountsDialog extends StatefulWidget {
  const BankAccountsDialog({super.key, required this.initial});
  final BankBook initial;
  @override
  State<BankAccountsDialog> createState() => _BankAccountsDialogState();
}

class _BankAccountsDialogState extends State<BankAccountsDialog> {
  late BankBook _book = widget.initial;
  late final Future<BankCatalog> _catalog = BankCatalog.load();

  Future<void> _edit([SavedBankAccount? old]) async {
    try {
      final catalog = await _catalog;
      if (!mounted) return;
      final saved = await showDialog<SavedBankAccount>(
        context: context,
        builder: (ctx) => BankAccountEditor(catalog: catalog, initial: old),
      );
      if (!mounted || saved == null) return;
      final newList = [..._book.accounts.where((a) => a.id != saved.id), saved];
      setState(() => _book = _book.copyWith(
        accounts: newList,
        defaultId: _book.defaultId ?? saved.id,
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được ngân hàng: ' + e.toString())));
    }
  }

  Future<void> _pickLogo(String slot) async {
    try {
      final path = await BrandLogoStorage.importLogo(slot: slot);
      if (path == null || !mounted) return;
      setState(() => _book = slot == 'center'
          ? _book.copyWith(centerLogoPath: path)
          : _book.copyWith(footerLogoPath: path));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không mở được ảnh logo: ' + e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    child: SafeArea(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 550, maxHeight: 800),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 8, 8, 6),
          child: Row(children: [
            const Expanded(child: Text('TÀI KHOẢN NGÂN HÀNG VIETQR',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
            IconButton(onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close)),
          ])),
        const Text('Chọn ngân hàng theo tên; BIN được điền tự động.',
          style: TextStyle(color: Colors.white60, fontSize: 12)),
        Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [
          if (_book.accounts.isEmpty)
            const Padding(padding: EdgeInsets.all(12),
              child: Text('Chưa có tài khoản nhận chuyển khoản.')),
          for (final saved in _book.accounts)
            Card(child: ListTile(
              leading: Icon(_book.selected?.id == saved.id
                  ? Icons.check_circle : Icons.account_balance,
                color: _book.selected?.id == saved.id
                  ? const Color(0xFF2ED473) : Colors.white70),
              title: Text(saved.bankName),
              subtitle: Text(saved.account.accountNumber + '\n' +
                saved.account.accountName),
              isThreeLine: true,
              onTap: () => setState(() =>
                _book = _book.copyWith(defaultId: saved.id)),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _edit(saved);
                  if (value == 'delete') {
                    final remaining = _book.accounts
                        .where((a) => a.id != saved.id).toList();
                    setState(() => _book = BankBook(
                      accounts: remaining,
                      defaultId: remaining.isEmpty ? null :
                        (_book.defaultId == saved.id
                          ? remaining.first.id : _book.defaultId),
                      centerLogoPath: _book.centerLogoPath,
                      footerLogoPath: _book.footerLogoPath,
                    ));
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sửa')),
                  PopupMenuItem(value: 'delete', child: Text('Xóa')),
                ],
              ),
            )),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _book.accounts.length < 15 ? () => _edit() : null,
            icon: const Icon(Icons.add),
            label: const Text('Thêm tài khoản ngân hàng')),
          const Divider(height: 25),
          const Text('LOGO TRÊN MÃ QR',
            style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 7),
          const Text('Logo tròn giữa QR tối đa 13% chiều rộng, giữ '
            'nền trắng vùng quét. Logo bên dưới rộng gần bằng QR.',
            style: TextStyle(fontSize: 11, color: Colors.white60)),
          const SizedBox(height: 9),
          if (_book.centerLogoPath != null)
            Center(child: SizedBox(width: 50, height: 50,
              child: ClipOval(child: BrandLogoView(
                path: _book.centerLogoPath!)))),
          OutlinedButton.icon(onPressed: () => _pickLogo('center'),
            icon: const Icon(Icons.image_outlined),
            label: const Text('Tải logo tròn ở giữa QR')),
          if (_book.centerLogoPath != null)
            TextButton(onPressed: () => setState(() =>
              _book = _book.copyWith(removeCenterLogo: true)),
              child: const Text('Bỏ logo giữa')),
          const SizedBox(height: 10),
          if (_book.footerLogoPath != null)
            Center(child: SizedBox(width: 220, height: 75,
              child: BrandLogoView(path: _book.footerLogoPath!))),
          OutlinedButton.icon(onPressed: () => _pickLogo('footer'),
            icon: const Icon(Icons.branding_watermark_outlined),
            label: const Text('Tải logo thương hiệu dưới QR')),
          if (_book.footerLogoPath != null)
            TextButton(onPressed: () => setState(() =>
              _book = _book.copyWith(removeFooterLogo: true)),
              child: const Text('Bỏ logo phía dưới')),
          const Text('Hỗ trợ PNG, JPG/JPEG, WebP, GIF, BMP, SVG '
            'và giữ nền trong suốt. Ảnh được lưu riêng trên thiết bị.',
            style: TextStyle(fontSize: 11, color: Colors.white60)),
        ])),
        Padding(padding: const EdgeInsets.all(12),
          child: SizedBox(width: double.infinity, child: FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('LƯU TÀI KHOẢN & LOGO'),
            onPressed: () {
              try {
                _book.validate();
                Navigator.pop(context, _book);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi: ' + e.toString())));
              }
            },
          ))),
      ]),
    )),
  );
}

class BankAccountEditor extends StatefulWidget {
  const BankAccountEditor({super.key, required this.catalog, this.initial});
  final BankCatalog catalog;
  final SavedBankAccount? initial;
  @override
  State<BankAccountEditor> createState() => _BankAccountEditorState();
}

class _BankAccountEditorState extends State<BankAccountEditor> {
  late final TextEditingController _number = TextEditingController(
    text: widget.initial?.account.accountNumber ?? '');
  late final TextEditingController _owner = TextEditingController(
    text: widget.initial?.account.accountName ?? '');
  VietQrBank? _bank;
  String? _error;

  @override
  void initState() {
    super.initState();
    final oldBin = widget.initial?.account.bankBin;
    for (final bank in widget.catalog.banks) {
      if (bank.bin == oldBin) { _bank = bank; break; }
    }
  }
  @override
  void dispose() {
    _number.dispose(); _owner.dispose();
    super.dispose();
  }

  Future<void> _chooseBank() async {
    final search = TextEditingController();
    final chosen = await showModalBottomSheet<VietQrBank>(
      context: context, showDragHandle: true, isScrollControlled: true,
      builder: (ctx) => SafeArea(child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: StatefulBuilder(builder: (ctx, update) => SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .68,
          child: Column(children: [
            Padding(padding: const EdgeInsets.all(12), child: TextField(
              controller: search, autofocus: true,
              onChanged: (_) => update(() {}),
              decoration: const InputDecoration(
                labelText: 'Tìm tên ngân hàng hoặc BIN',
                prefixIcon: Icon(Icons.search)))),
            Expanded(child: ListView(children: [
              for (final bank in widget.catalog.search(search.text))
                ListTile(
                  title: Text(bank.shortName),
                  subtitle: Text(bank.name + ' • BIN ' + bank.bin),
                  enabled: bank.transferSupported,
                  trailing: !bank.transferSupported
                    ? const Text('Chưa hỗ trợ nhận', style:
                        TextStyle(fontSize: 10, color: Colors.orangeAccent))
                    : null,
                  onTap: bank.transferSupported
                    ? () => Navigator.pop(ctx, bank) : null,
                ),
            ])),
          ]),
        )),
      )),
    );
    search.dispose();
    if (chosen != null && mounted) setState(() => _bank = chosen);
  }

  void _save() {
    final bank = _bank;
    if (bank == null) {
      setState(() => _error = 'Chưa chọn ngân hàng'); return;
    }
    final account = VietQrAccount(
      bankBin: bank.bin,
      accountNumber: _number.text.trim().replaceAll(' ', ''),
      accountName: _owner.text.trim(),
    );
    if (!account.isValid) {
      setState(() => _error =
        'Nhập tên chủ tài khoản và số tài khoản (chữ/số, tối đa 19 ký tự).');
      return;
    }
    Navigator.pop(context, SavedBankAccount(
      id: widget.initial?.id ??
        'account_' + DateTime.now().microsecondsSinceEpoch.toString(),
      bankName: bank.shortName, account: account,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ?
      'Thêm tài khoản nhận tiền' : 'Sửa tài khoản nhận tiền'),
    content: SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        OutlinedButton.icon(
          onPressed: _chooseBank, icon: const Icon(Icons.account_balance),
          label: Text(_bank == null
            ? 'Chọn ngân hàng theo tên'
            : _bank!.shortName + ' • ' + _bank!.bin),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _number, maxLength: 19,
          decoration: const InputDecoration(
            labelText: 'Số tài khoản / Alias')),
        TextField(
          controller: _owner, maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Tên chủ tài khoản')),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        const Text('Dữ liệu được lưu trên máy. Ứng dụng chưa xác minh '
          'chủ tài khoản với ngân hàng.',
          style: TextStyle(color: Colors.white60, fontSize: 11)),
      ]),
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context),
        child: const Text('Hủy')),
      FilledButton(onPressed: _save, child: const Text('Lưu')),
    ],
  );
}
