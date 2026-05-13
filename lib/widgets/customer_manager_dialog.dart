import 'package:flutter/material.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';
import 'package:donapos_mobile/api_service.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class CustomerManagerDialog extends StatefulWidget {
  final Map<String, dynamic>? initialCustomer;
  final Function(Map<String, dynamic>)? onSelect;

  final bool isSelectionOnly;

  const CustomerManagerDialog({
    super.key, 
    this.initialCustomer,
    this.onSelect,
    this.isSelectionOnly = false,
  });

  @override
  State<CustomerManagerDialog> createState() => _CustomerManagerDialogState();
}

class _CustomerManagerDialogState extends State<CustomerManagerDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isManualKeyboard = false;

  List<Map<String, dynamic>> _allContacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  bool _isLoading = true;
  bool _isEditing = false;
  int? _editingLocalId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadContacts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
    });
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getAllContacts();
    setState(() {
      _allContacts = data;
      _filteredContacts = data;
      _isLoading = false;
    });
  }

  void _filterContacts(String query) {
    setState(() {
      _filteredContacts = _allContacts
          .where((c) => 
               (c['name']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false) || 
               (c['contact_id']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false) ||
               (c['mobile']?.toString().contains(query) ?? false))
          .toList();
    });
  }

  void _handleBarcode(String code) {
      if (code.isEmpty) return;
      _filterContacts(code);
      
      // If exactly one match, auto-select it
      if (_filteredContacts.length == 1) {
          final c = _filteredContacts.first;
          if (widget.onSelect != null) widget.onSelect!(c);
          Navigator.pop(context);
      }
  }

  void _prepareEdit(Map<String, dynamic> contact) {
    setState(() {
      _isEditing = true;
      _editingLocalId = contact['id'];
      _nameController.text = contact['name'] ?? '';
      _mobileController.text = contact['mobile'] ?? '';
      _emailController.text = contact['email'] ?? '';
      _addressController.text = contact['address'] ?? '';
      _cityController.text = contact['city'] ?? '';
      _stateController.text = contact['state'] ?? '';
      _zipController.text = contact['zip_code'] ?? '';
      if (widget.isSelectionOnly) _tabController.animateTo(1);
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _editingLocalId = null;
      _nameController.clear();
      _mobileController.clear();
      _emailController.clear();
      _addressController.clear();
      _cityController.clear();
      _stateController.clear();
      _zipController.clear();
    });
  }

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final Map<String, dynamic> customerData = {
        'name': _nameController.text,
        'mobile': _mobileController.text,
        'email': _emailController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'state': _stateController.text,
        'zip_code': _zipController.text,
        'is_synced': 0,
      };

      try {
        // --- INSTANT UPLOAD TO VPS ---
        final api = ApiService();
        final serverResult = await api.uploadNewCustomer(customerData);
        
        if (serverResult != null) {
            customerData['server_id'] = serverResult['id'];
            customerData['contact_id'] = serverResult['contact_id'];
            customerData['is_synced'] = 1;
        }

        if (_editingLocalId != null) {
          customerData['id'] = _editingLocalId;
        }
        
        final int id = await DatabaseHelper.instance.insertContact(customerData);
        customerData['id'] = id;

        setState(() => _isLoading = false);

        if (widget.onSelect != null) {
          widget.onSelect!(customerData);
          if (mounted) Navigator.pop(context);
        } else {
          _cancelEdit();
          _loadContacts();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PELANGGAN BERHASIL DISIMPAN (SINKRON VPS)'))
            );
          }
        }
      } catch (e) {
          print('Save Error: $e');
          setState(() => _isLoading = false);
          // Fallback to local save
          final int id = await DatabaseHelper.instance.insertContact(customerData);
          customerData['id'] = id;
          if (widget.onSelect != null) {
            widget.onSelect!(customerData);
            if (mounted) Navigator.pop(context);
          } else {
            _cancelEdit();
            _loadContacts();
          }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return GlassDialog(
      title: isKeyboardOpen ? '' : (widget.isSelectionOnly ? 'PELANGGAN' : 'PELANGGAN'),
      icon: isKeyboardOpen ? Icons.keyboard_hide : Icons.people,
      width: widget.isSelectionOnly ? 700 : 950,
      height: widget.isSelectionOnly ? 700 : (isKeyboardOpen ? 180 : 160),
      actions: widget.isSelectionOnly ? [
          Container(
            width: 250,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(4)
            ),
            child: TextField(
                key: ValueKey('search_kb_$_isManualKeyboard'),
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                onChanged: _filterContacts,
                onSubmitted: _handleBarcode,
                keyboardType: _isManualKeyboard ? TextInputType.text : TextInputType.none,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 16),
                    hintText: 'CARI NAMA/CODE...',
                    hintStyle: TextStyle(fontSize: 10),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10)
                ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
              icon: Icon(_isManualKeyboard ? Icons.keyboard_hide : Icons.keyboard, color: MetroColors.primary),
              onPressed: () {
                  setState(() {
                      _isManualKeyboard = !_isManualKeyboard;
                  });
                  
                  if (_isManualKeyboard) {
                      _searchFocusNode.requestFocus();
                      SystemChannels.textInput.invokeMethod('TextInput.show');
                  } else {
                      SystemChannels.textInput.invokeMethod('TextInput.hide');
                  }
              },
          )
      ] : null,
      content: widget.isSelectionOnly ? _buildSelectionMode(isKeyboardOpen) : _buildManagerMode(isKeyboardOpen),
    );
  }

  Widget _buildSelectionMode(bool isKeyboardOpen) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelPadding: const EdgeInsets.symmetric(vertical: 8),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
          indicatorColor: MetroColors.primary,
          labelColor: MetroColors.primary,
          unselectedLabelColor: Colors.black26,
          tabs: const [
            Tab(text: 'PILIH PELANGGAN'),
            Tab(text: 'TAMBAH BARU'),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildListPage(isKeyboardOpen),
              _buildAddPage(),
            ],
          ),
        ),
    ],
    );
  }

  Widget _buildListPage(bool isKeyboardOpen) {
    return Column(
      children: [
        Expanded(child: _buildSelectionList()),
      ],
    );
  }

  Widget _buildAddPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildCompactField('NAMA (WAJIB)', _nameController, Icons.person, required: true),
              const SizedBox(height: 12),
              _buildCompactField('MOBILE (WAJIB)', _mobileController, Icons.phone, required: true),
              const SizedBox(height: 12),
              _buildCompactField('EMAIL', _emailController, Icons.email),
              const SizedBox(height: 12),
              _buildCompactField('ALAMAT', _addressController, Icons.location_on),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildCompactField('KOTA', _cityController, Icons.location_city)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCompactField('PROVINSI', _stateController, Icons.map)),
                ],
              ),
              const SizedBox(height: 12),
              _buildCompactField('KODE POS', _zipController, Icons.markunread_mailbox),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetroColors.primary,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  onPressed: _saveCustomer,
                  child: const Text('SIMPAN & PILIH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagerMode(bool isKeyboardOpen) {
    return Form(
      key: _formKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _buildCompactField('NAMA...', _nameController, Icons.person, required: true)),
          const SizedBox(width: 8),
          Expanded(child: _buildCompactField('TELEPON...', _mobileController, Icons.phone, required: true)),
          const SizedBox(width: 8),
          Expanded(child: _buildCompactField('EMAIL...', _emailController, Icons.email)),
          const SizedBox(width: 8),
          Expanded(child: _buildCompactField('ALAMAT...', _addressController, Icons.location_on)),
          const SizedBox(width: 12),
          SizedBox(
            height: 42,
            width: 80,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEditing ? Colors.orange : MetroColors.primary,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: EdgeInsets.zero,
                elevation: 0,
              ),
              onPressed: _saveCustomer,
              child: Text(_isEditing ? 'UPDATE' : 'SIMPAN', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
            ),
          ),
          if (_isEditing) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black26),
              onPressed: _cancelEdit,
            )
          ]
        ],
      ),
    );
  }

  Widget _buildCompactField(String hint, TextEditingController controller, IconData icon, {bool required = false}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: MetroColors.text, fontSize: 11, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black26, fontSize: 9),
        prefixIcon: Icon(icon, color: MetroColors.primary, size: 14),
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Colors.black.withOpacity(0.1))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      validator: required ? (val) => val == null || val.isEmpty ? '!' : null : null,
    );
  }

  Widget _buildSelectionList() {
    if (_isLoading) return const Center(child: DonaposLoader(size: 60));
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredContacts.length + 1,
      separatorBuilder: (_, __) => const Divider(color: Colors.black12),
      itemBuilder: (ctx, i) {
        if (i == 0) {
            if (_searchController.text.isNotEmpty) return const SizedBox.shrink();
            return ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.black12, child: Icon(Icons.people, color: Colors.black54)),
                title: const Text('PELANGGAN UMUM / WALK-IN', style: TextStyle(color: MetroColors.text, fontWeight: FontWeight.bold, fontSize: 11)),
                onTap: () {
                    if (widget.onSelect != null) widget.onSelect!({'name': 'Pelanggan Umum'});
                    Navigator.pop(context);
                },
            );
        }
        final c = _filteredContacts[i-1];
        final isLocal = c['server_id'] == null;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isLocal ? Colors.orange.withOpacity(0.1) : MetroColors.primary.withOpacity(0.1), 
            child: Icon(isLocal ? Icons.cloud_upload : Icons.person, color: isLocal ? Colors.orange : MetroColors.primary, size: 16)
          ),
          title: Text(c['name'] ?? '-', style: const TextStyle(color: MetroColors.text, fontWeight: FontWeight.bold, fontSize: 11)),
          subtitle: Text("${c['contact_id'] ?? '-'} | ${c['mobile'] ?? '-'}", style: const TextStyle(color: Colors.black45, fontSize: 9)),
          trailing: const Icon(Icons.chevron_right, color: Colors.black26),
          onTap: () {
            if (widget.onSelect != null) widget.onSelect!(c);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}
