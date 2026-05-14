import 'package:flutter/material.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/models.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:donapos_mobile/utils_ui.dart';
import 'package:donapos_mobile/widgets/donapos_image.dart';

class WaiterManagementDialog extends StatefulWidget {
  const WaiterManagementDialog({super.key});

  @override
  State<WaiterManagementDialog> createState() => _WaiterManagementDialogState();
}

class _WaiterManagementDialogState extends State<WaiterManagementDialog> {
  List<AppUser> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getAllUsers();
      setState(() {
        _users = data.map((e) => AppUser.fromMap(e)).toList();
      });
    } catch (e) {
      print("Error loading users: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleWaiter(AppUser user, bool value) async {
    try {
      await DatabaseHelper.instance.updateUserWaiterStatus(user.id, value);
      await _loadUsers(); // Refresh
    } catch (e) {
      showAppModal(context, title: 'ERROR', message: 'Gagal update status waiter: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
      title: 'MANAJEMEN WAITER',
      icon: Icons.people,
      width: 600,
      height: 700,
      content: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.withOpacity(0.1),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Aktifkan switch pada staff yang bertugas sebagai Waiter agar muncul di menu pilihan Waiter pada halaman Kasir.",
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: DonaposLoader(size: 60))
                : _users.isEmpty
                    ? const Center(child: Text("Belum ada data staff. Silakan sync terlebih dahulu."))
                    : ListView.separated(
                        itemCount: _users.length,
                        separatorBuilder: (ctx, i) => const Divider(),
                        itemBuilder: (ctx, i) {
                          final user = _users[i];
                          final isWaiter = user.isWaiter == 1;
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: (user.profileImage != null && user.profileImage!.isNotEmpty)
                                  ? DonaposImage.provider(user.profileImage!)
                                  : null,
                              child: (user.profileImage == null || user.profileImage!.isEmpty)
                                  ? const Icon(Icons.person, color: Colors.grey)
                                  : null,
                            ),
                            title: Text(user.firstName.toUpperCase() + (user.lastName != null ? ' ${user.lastName}' : '').toUpperCase(), 
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(user.username, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            trailing: Switch(
                              value: isWaiter,
                              activeColor: MetroColors.primary,
                              onChanged: (val) => _toggleWaiter(user, val),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 16),
          MetroButton(
            label: 'TUTUP',
            icon: Icons.close,
            color: MetroColors.text,
            isSecondary: true,
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }
}
