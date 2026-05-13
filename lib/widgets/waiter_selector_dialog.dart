import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/models.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';

class WaiterSelectorDialog extends StatefulWidget {
  final Function(AppUser) onSelect;

  const WaiterSelectorDialog({super.key, required this.onSelect});

  @override
  State<WaiterSelectorDialog> createState() => _WaiterSelectorDialogState();
}

class _WaiterSelectorDialogState extends State<WaiterSelectorDialog> {
  List<AppUser> _waiters = [];
  List<AppUser> _filteredWaiters = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWaiters();
  }

  Future<void> _loadWaiters() async {
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseHelper.instance.getAllUsers();
      final users = data.map((e) => AppUser.fromMap(e)).toList();
      setState(() {
        _waiters = users.where((u) => u.isWaiter == 1).toList();
        _filteredWaiters = _waiters;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading waiters: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filter(String query) {
    setState(() {
      _filteredWaiters = _waiters
          .where((w) => 
              w.firstName.toLowerCase().contains(query.toLowerCase()) || 
              (w.lastName?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
              w.username.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
        title: 'PILIH WAITER',
        icon: Icons.badge,
        width: 500,
        height: 600,
        content: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.zero,
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filter,
                style: const TextStyle(color: MetroColors.text, fontSize: 13, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: 'CARI NAMA WAITER...',
                  hintStyle: TextStyle(color: Colors.black26, fontSize: 10, letterSpacing: 1),
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: Colors.black26, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: DonaposLoader(size: 60))
                  : _filteredWaiters.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people_outline, size: 48, color: Colors.black12),
                              const SizedBox(height: 16),
                              Text(_waiters.isEmpty 
                                ? "BELUM ADA STAFF DENGAN STATUS WAITER.\nAKTIFKAN DI PENGATURAN STAFF."
                                : "WAITER TIDAK DITEMUKAN.", 
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _filteredWaiters.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final w = _filteredWaiters[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: MetroColors.primary.withOpacity(0.1),
                                child: const Icon(Icons.person, color: MetroColors.primary, size: 18),
                              ),
                              title: Text(w.firstName.toUpperCase() + (w.lastName != null ? ' ${w.lastName}' : '').toUpperCase(), 
                                  style: const TextStyle(color: MetroColors.text, fontWeight: FontWeight.w900, fontSize: 12)),
                              subtitle: Text(w.username, style: const TextStyle(fontSize: 9, color: Colors.black45)),
                              trailing: const Icon(Icons.chevron_right, color: Colors.black12),
                              onTap: () {
                                widget.onSelect(w);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
