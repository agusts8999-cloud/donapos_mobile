import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/api_service.dart';
import 'package:donapos_mobile/utils_ui.dart';
import 'package:donapos_mobile/screens/pos_screen.dart';
import 'package:donapos_mobile/screens/config_screen.dart';
import 'package:donapos_mobile/screens/admin_dashboard.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/models.dart';
import 'package:donapos_mobile/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:donapos_mobile/widgets/initial_cash_dialog.dart';
import 'package:donapos_mobile/widgets/terms_agreement_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:donapos_mobile/language_provider.dart';
import 'package:donapos_mobile/utils_scaler.dart';

class LoginScreen extends StatefulWidget {
  final bool showAdminLogin;
  const LoginScreen({super.key, this.showAdminLogin = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  
  final _apiService = ApiService();
  bool _isLoading = false;
  List<AppUser> _users = [];
  AppUser? _selectedUser;
  late bool _isSetupMode;
  bool _isDemoMode = false;
  bool _isFirstTimeLogin = false;

  String _businessName = '';
  String _locationName = '';
  Map<String, dynamic> _systemStatus = {};
  String _qrMainUrl = 'https://donapos.com';
  String _qrBackofficeUrl = 'https://donapos.serverzone.web.id';

  // FIX: Persistent FocusNode
  late FocusNode _pinFocusNode;

  @override
  void initState() {
    super.initState();
    _isSetupMode = widget.showAdminLogin;
    _pinFocusNode = FocusNode();
    _loadQrSettings();
    _loadUsers();
    _loadInfo();
    _loadSystemStatus();
    _loadDemoStatus();
    _checkFirstTime();
  }

  Future<void> _loadQrSettings() async {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
          setState(() {
              _qrMainUrl = prefs.getString('qr_main_url') ?? 'https://donapos.com';
              _qrBackofficeUrl = prefs.getString('qr_backoffice_url') ?? 'https://donapos.serverzone.web.id';
          });
      }
  }

  Future<void> _checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hasLoggedBefore = prefs.getBool('has_logged_in_before') ?? false;
    if (!hasLoggedBefore && mounted) {
      setState(() => _isFirstTimeLogin = true);
    }
  }

  Future<void> _loadDemoStatus() async {
      final prefs = await SharedPreferences.getInstance();
      setState(() { _isDemoMode = prefs.getBool('is_demo_mode') ?? false; });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ScreenScaler.init(context);
  }

  @override
  void dispose() {
    _pinFocusNode.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSystemStatus() async {
      final status = await DatabaseHelper.instance.getSystemStatus();
      setState(() { _systemStatus = status; });
  }
  
  Future<void> _loadInfo() async {
      final bn = await _apiService.getBusinessName();
      final ln = await _apiService.getLocationName();
      setState(() {
          _businessName = bn;
          _locationName = ln;
      });
  }
  
  Future<void> _loadUsers() async {
      final userMaps = await DatabaseHelper.instance.getAllUsers();
      if (userMaps.isEmpty) {
          setState(() { _isSetupMode = true; });
      } else {
          var users = userMaps.map((e) => AppUser.fromMap(e)).toList();
          final prefs = await SharedPreferences.getInstance();
          final scope = prefs.getString('access_scope');
          if (scope == 'single') {
              final scopeId = prefs.getInt('scoped_user_id');
              if (scopeId != null) {
                  users = users.where((u) => u.id == scopeId).toList();
              }
          }
          final lastUserId = prefs.getInt('last_user_id');
          AppUser? lastUser;
          if (lastUserId != null) {
              try { lastUser = users.firstWhere((u) => u.id == lastUserId); } catch (_) {}
          }
          setState(() { 
            _users = users; 
            _selectedUser = lastUser; 
            if (!widget.showAdminLogin) _isSetupMode = false; 
          });
      }
  }

  void _navToPos() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PosScreen()),
      (route) => false,
    );
  }

  void _adminLogin() async {
    setState(() => _isLoading = true);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final lp = Provider.of<LanguageProvider>(context, listen: false);

    bool loginSuccess = false;
    Map<String, dynamic>? userInfo;

    // 1. Try Local Login First for Speed (Offline-First)
    final localUser = await DatabaseHelper.instance.getUserByUsername(username);
    final storedPin = localUser?['pin']?.toString() ?? '';
    final prefs = await SharedPreferences.getInstance();
    final savedSyncPass = prefs.getString('sync_admin_pass');

    bool isLocalValid = false;
    if (localUser != null && storedPin.isNotEmpty && storedPin == password) {
        isLocalValid = true;
    } else if (prefs.getString('sync_admin_user')?.toLowerCase() == username.toLowerCase() && savedSyncPass == password) {
        isLocalValid = true;
    }

    if (isLocalValid) {
        debugPrint("Local login successful, bypassing online check for speed.");
        loginSuccess = true;
        // Trigger background sync but don't wait for it
        _apiService.login(username, password).then((success) {
            if (success) {
                _apiService.syncBusinessDetails().catchError((_) {});
                _apiService.syncUsers().catchError((_) {});
                _loadInfo();
            }
        }).catchError((_) {});
    } else {
        // 2. Try Online Login (with strict timeout)
        try {
            loginSuccess = await _apiService.login(username, password).timeout(const Duration(seconds: 5));
            if (loginSuccess) {
                _apiService.syncBusinessDetails().catchError((_) {});
                _apiService.syncUsers().catchError((_) {});
                try {
                    userInfo = await _apiService.getUserInfo().timeout(const Duration(seconds: 3));
                } catch (e) {
                    debugPrint("Get user info error: $e");
                }
                _loadInfo();
            }
        } catch (e) {
            debugPrint("Online login timeout/error: $e");
        }
    }

    // 2. Process Result
    if (loginSuccess) {
        final prefs = await SharedPreferences.getInstance();
        final isDemo = await _apiService.isDemo();

        if (isDemo && username == 'aurel') {
             // Demo Cashier -> Go directly to staff selection (scoped)
             await prefs.setString('access_scope', 'single');
             await prefs.setInt('scoped_user_id', 6); // Aurel ID is 6 in seeding
             setState(() => _isLoading = false);
             await _loadUsers();
             setState(() { _isSetupMode = false; });
             return;
        }

        // IMPROVED ADMIN CHECK
        bool isAdmin = false;
        if (userInfo != null) {
            final u = userInfo!;
            isAdmin = u['is_admin'] == true || 
                      u['is_admin'] == 1 || 
                      u['is_admin'].toString().toLowerCase() == 'true';
            
            // Fallback: Check jabatan/role name if provided in userInfo
            if (!isAdmin && u['role_name'] != null) {
                isAdmin = u['role_name'].toString().toLowerCase().contains('admin');
            }
        }
        
        // Final Fallback: Check local DB or Sync Admin Credentials
        if (!isAdmin) {
            final localUser = await DatabaseHelper.instance.getUserByUsername(username);
            final savedSyncUser = prefs.getString('sync_admin_user');
            
            if (localUser != null && (localUser['is_admin'] == 1 || localUser['isAdmin'] == 1)) {
                isAdmin = true;
            } else if (savedSyncUser != null && savedSyncUser.toLowerCase() == username.toLowerCase()) {
                // If it's the master sync user, they are definitely an Admin
                isAdmin = true;
            }
        }
        
        setState(() => _isLoading = false);
        
        if (isAdmin) {
             await prefs.setString('access_scope', 'all');
             await prefs.setString('last_user_name', username);
             
             // SIMPAN UNTUK SINKRONISASI OTOMATIS (Dinamis per Lokasi)
             await prefs.setString('sync_admin_user', username);
             await prefs.setString('sync_admin_pass', _passwordController.text);
             
             // REVISI: Tampilkan dialog pilihan Admin vs Kasir
             if (mounted) {
               showDialog(
                 context: context,
                 barrierDismissible: false,
                 builder: (ctx) => AlertDialog(
                   titlePadding: EdgeInsets.zero,
                   contentPadding: EdgeInsets.zero,
                   shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                   content: Container(
                     width: 450.sc,
                     color: MetroColors.background,
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Container(
                           width: double.infinity,
                           padding: EdgeInsets.symmetric(vertical: 20.sc),
                           color: MetroColors.primary,
                           child: Column(
                             children: [
                               Icon(Icons.verified_user, color: Colors.white, size: 40.sc),
                               SizedBox(height: 12.sc),
                               Text('LOGIN ADMIN BERHASIL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp, letterSpacing: 1.2.sc)),
                             ],
                           ),
                         ),
                         Padding(
                           padding: EdgeInsets.all(24.sc),
                           child: Text('Halo Admin! Silakan pilih menu tujuan Anda hari ini:', textAlign: TextAlign.center, style: TextStyle(fontSize: 16.sp)),
                         ),
                         Padding(
                           padding: EdgeInsets.fromLTRB(24.sc, 0, 24.sc, 24.sc),
                           child: Row(
                             children: [
                               Expanded(
                                 child: MetroButton(
                                   label: 'ADMIN MENU',
                                   icon: Icons.dashboard_customize,
                                   onPressed: () {
                                     Navigator.pop(ctx);
                                     _showAdminDashboard();
                                   },
                                 ),
                               ),
                               SizedBox(width: 16.sc),
                               Expanded(
                                 child: MetroButton(
                                   label: 'PILIH KASIR',
                                   icon: Icons.point_of_sale,
                                   isSecondary: true,
                                   color: MetroColors.secondary,
                                   onPressed: () async {
                                     Navigator.pop(ctx);
                                     await _loadUsers();
                                     setState(() { _isSetupMode = false; });
                                   },
                                 ),
                               ),
                             ],
                           ),
                         ),
                       ],
                     ),
                   ),
                 ),
               );
             }
        } else {
             await prefs.setString('access_scope', 'single');
             if (userInfo != null) await prefs.setInt('scoped_user_id', userInfo!['id']);
             final user = await DatabaseHelper.instance.getUserByUsername(username);
             if (user != null) {
                 await _loadUsers();
                 setState(() { _isSetupMode = false; });
             } else {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login Gagal: User tidak valid.')));
             }
        }
    } else {
        // 3. Fallback to Local Login if Offline or Server Error
        final prefs = await SharedPreferences.getInstance();
        final savedSyncUser = prefs.getString('sync_admin_user');
        final savedSyncPass = prefs.getString('sync_admin_pass');

        final localUser = await DatabaseHelper.instance.getUserByUsername(username);
        final storedPin = localUser?['pin']?.toString() ?? '';
        
        bool isOfflineAuthValid = false;
        
        if (savedSyncUser != null && savedSyncUser.toLowerCase() == username.toLowerCase() && savedSyncPass == password) {
             isOfflineAuthValid = true;
        } else if (localUser != null && storedPin.isNotEmpty && storedPin == password) {
             isOfflineAuthValid = true;
        }
        
        if (isOfflineAuthValid) {
            // We have this user locally & password matches, allow bypass to staff selection
            setState(() => _isLoading = false);
            await _loadUsers();
            setState(() { _isSetupMode = false; });
        } else {
            // Not found online AND not found locally (or wrong password)
            setState(() => _isLoading = false);
            final userCount = await DatabaseHelper.instance.getUserCount();
            
            if (userCount > 0) {
                 // Users exist but not this one or password mismatch
                 ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(lp.translate('login_failed')))
                );
            } else {
                 // No users at all -> Cannot login offline
                 ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(lp.translate('offline_mode_not_ready')))
                );
            }
        }
    }
  }

  void _showAdminDashboard() async {
      await Navigator.push(
          context, 
          MaterialPageRoute(builder: (ctx) => AdminDashboard(username: _usernameController.text))
      );
      await _loadUsers();
  }

  Widget _buildLanguageSwitch() {
    final lp = Provider.of<LanguageProvider>(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.sc, vertical: 4.sc),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.sc),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _langOpt('ID', AppLanguage.id, lp),
          SizedBox(width: 8.sc),
          _langOpt('EN', AppLanguage.en, lp),
        ],
      ),
    );
  }

  Widget _langOpt(String label, AppLanguage lang, LanguageProvider lp) {
    bool active = lp.currentLanguage == lang;
    return InkWell(
      onTap: () => lp.setLanguage(lang),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.sc, vertical: 4.sc),
        decoration: BoxDecoration(
          color: active ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(15.sc),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white38, // Fallback for color
            fontWeight: FontWeight.w900,
            fontSize: 10.sp,
          ),
        ),
      ),
    );
  }
  
  void _pinLogin() async {
      if (_selectedUser == null) return;
      
      if (_pinController.text == _selectedUser!.pin) {
          setState(() => _isLoading = true); // Show loading
          
          try {
              final prefs = await SharedPreferences.getInstance();
              
              // Removed background authenticateClient call to ensure instant offline-first login.
              // SyncService will handle authentication in the background if needed.

              bool isOpen = prefs.getBool('is_cashier_open') ?? false;
              if (!isOpen) {
                  if (mounted) {
                      setState(() => _isLoading = false); // Hide loading for dialog
                      final success = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => InitialCashDialog(
                              onConfirm: (amount) async {
                                  final p = await SharedPreferences.getInstance();
                                  await p.setBool('is_cashier_open', true);
                                  await p.setDouble('initial_cash', amount);
                                  await p.setString('opened_by', _selectedUser!.firstName);
                                  await p.setString('opened_at', DateTime.now().toIso8601String());
                                  
                                  await p.setInt('last_user_id', _selectedUser!.id);
                                  await p.setString('last_user_name', _selectedUser!.firstName);
                                  await p.setBool('last_user_is_admin', _selectedUser!.isAdmin == 1);
                                  await p.setBool('has_logged_in_before', true);
                              },
                          )
                      );
                      if (success == true && mounted) {
                          _navToPos();
                      }
                  }
              } else {
                  await prefs.setInt('last_user_id', _selectedUser!.id);
                  await prefs.setString('last_user_name', _selectedUser!.firstName);
                  await prefs.setBool('last_user_is_admin', _selectedUser!.isAdmin == 1);
                  await prefs.setBool('has_logged_in_before', true);
                  if (mounted) {
                    setState(() => _isFirstTimeLogin = false);
                    _navToPos();
                  }
              }
          } catch (e) {
              if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login Error: $e')));
                  setState(() => _isLoading = false);
              }
          }
      } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN SALAH!')));
          _pinController.clear();
      }
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    if (_isSetupMode) return _buildSetupScreen(lp);
    if (_selectedUser != null) return _buildPinScreen(lp);
    return _buildUserSelectScreen(lp);
  }
  
  Widget _buildSetupScreen(LanguageProvider lp) {
      final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

      Widget brandingPanel = Container(
          color: MetroColors.primary,
          padding: EdgeInsets.symmetric(horizontal: 32.sc, vertical: 24.sc),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                  _buildLanguageSwitch(),
                  SizedBox(height: 16.sc),
                  Image.asset('assets/images/logo.png', height: 80.sc, width: 80.sc, fit: BoxFit.contain),
                  Text('DonaPOS', style: TextStyle(fontSize: 40.sp, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.sc)),
                  if (_isDemoMode)
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 8.sc),
                      padding: EdgeInsets.symmetric(horizontal: 12.sc, vertical: 4.sc),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4.sc)),
                      child: Text('DEMO MODE ACTIVE (OFFLINE)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12.sp)),
                    ),
                  Text('Edisi FnB Plus', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white70)),
                  SizedBox(height: 8.sc),
                  Text('Versi ${AppConfig.appVersion} Build ${AppConfig.buildNumber}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.white38)),
                  SizedBox(height: 24.sc),
                  
                  // QR Codes Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        _buildQrItem('WEBSITE UTAMA', _qrMainUrl, size: 80.sc),
                        SizedBox(width: 24.sc),
                        _buildQrItem('BACK OFFICE', _qrBackofficeUrl, size: 80.sc),
                    ],
                  ),

                  SizedBox(height: 24.sc),
                  
                  SizedBox(
                      width: double.infinity,
                      child: TextButton(
                          onPressed: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigScreen()));
                              _loadDemoStatus();
                              _loadInfo();
                              _loadUsers();
                              _loadSystemStatus();
                          },
                          style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              padding: EdgeInsets.symmetric(vertical: 20.sc),
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          ),
                          child: Column(
                              children: [
                                  Icon(Icons.settings_ethernet, color: Colors.white, size: 28.sc),
                                  SizedBox(height: 8.sc),
                                  Text(lp.translate('erp_connection_setup').toUpperCase(), textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2.sc)),
                              ],
                          )
                      ),
                  ),
                  SizedBox(height: 16.sc),
                  Text('DONAPOS ERP CLOUD', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 10.sp, letterSpacing: 1.sc)),
                  SizedBox(height: 24.sc),
                  const DonaposFooter(),
              ],
          ),
      );

      Widget loginForm = Container(
        padding: EdgeInsets.symmetric(horizontal: isLandscape ? 80.sc : 40.sc),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Text(lp.translate('login'), style: TextStyle(fontSize: 28.8.sp, fontWeight: FontWeight.w900, color: MetroColors.text, letterSpacing: -1.sc)),
                SizedBox(height: 48.sc),
                MetroInput(label: lp.translate('username'), controller: _usernameController, hint: lp.translate('enter_username')),
                SizedBox(height: 24.sc),
                MetroInput(label: lp.translate('password'), controller: _passwordController, isPassword: true, hint: lp.translate('enter_password')),
                SizedBox(height: 48.sc),
                if (_isLoading) 
                    Center(child: DonaposLoader(size: 60.sc)) 
                else ...[
                    MetroButton(label: lp.translate('login_and_setup_pin'), onPressed: _adminLogin, isLarge: true),
                    if (_isDemoMode) ...[
                        SizedBox(height: 16.sc),
                        Row(
                            children: [
                                Expanded(
                                    child: MetroButton(
                                        label: 'ADMIN (TASHIA)',
                                        isSecondary: true,
                                        color: Colors.blueGrey,
                                        onPressed: () {
                                            _usernameController.text = 'tashia';
                                            _passwordController.text = '12345';
                                            _adminLogin();
                                        }
                                    ),
                                ),
                                SizedBox(width: 12.sc),
                                Expanded(
                                    child: MetroButton(
                                        label: 'KASIR (AUREL)',
                                        isSecondary: true,
                                        color: Colors.blueGrey,
                                        onPressed: () {
                                            _usernameController.text = 'aurel';
                                            _passwordController.text = '12345';
                                            _adminLogin();
                                        }
                                    ),
                                ),
                            ],
                        ),
                    ],
                ],
                SizedBox(height: 40.sc),
            ],
        ),
      );

      if (isLandscape) {
        return Scaffold(
            backgroundColor: MetroColors.background,
            body: Row(
                children: [
                    Expanded(
                      flex: 1, 
                      child: Container(
                        color: MetroColors.primary,
                        height: double.infinity,
                        child: Center(
                            child: SingleChildScrollView(
                                child: brandingPanel
                            )
                        ),
                      )
                    ),
                    Expanded(
                      flex: 1, 
                      child: Container(
                        height: double.infinity,
                        child: Center(
                            child: SingleChildScrollView(
                                child: Center(child: loginForm)
                            )
                        ),
                      )
                    ),
                ],
            ),
        );
      }

      return Scaffold(
          backgroundColor: MetroColors.background,
          body: SingleChildScrollView(
              child: Column(
                  children: [
                      Container(
                        width: double.infinity,
                        color: MetroColors.primary,
                        padding: const EdgeInsets.fromLTRB(40, 64, 40, 40),
                        child: Column(
                          children: [
                            _buildLanguageSwitch(),
                            const SizedBox(height: 24),
                            Image.asset('assets/images/logo.png', height: 72, width: 72, fit: BoxFit.contain),
                            const SizedBox(height: 24),
                            Text('DonaPOS FnB Plus', style: const TextStyle(fontSize: 21.6, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
                            if (_isDemoMode)
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                                child: const Text('DEMO MODE (OFFLINE)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10)),
                              ),
                            Text('Versi ${AppConfig.appVersion} Build ${AppConfig.buildNumber}', style: const TextStyle(fontSize: 12.6, fontWeight: FontWeight.bold, color: Colors.white70)),
                            const SizedBox(height: 24),
                            // QR Codes
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    _buildQrItem('WEBSITE', _qrMainUrl, size: 60),
                                    const SizedBox(width: 32),
                                    _buildQrItem('BACK OFFICE', _qrBackofficeUrl, size: 60),
                                ],
                            ),
                          ],
                        ),
                      ),
                      loginForm,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                        width: double.infinity,
                        color: MetroColors.primary,
                        child: Column(
                            children: [
                                SizedBox(
                                    width: double.infinity,
                                    child: TextButton(
                                        onPressed: () async {
                                            await Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigScreen()));
                                            _loadDemoStatus();
                                            _loadInfo();
                                            _loadUsers();
                                            _loadSystemStatus();
                                        },
                                        style: TextButton.styleFrom(
                                            backgroundColor: Colors.white.withOpacity(0.1),
                                            padding: const EdgeInsets.symmetric(vertical: 24),
                                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                        ),
                                        child: Column(
                                            children: [
                                                const Icon(Icons.settings_ethernet, color: Colors.white, size: 28),
                                                const SizedBox(height: 8),
                                                Text(lp.translate('erp_connection_setup').toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                            ],
                                        )
                                    ),
                                ),
                                const SizedBox(height: 16),
                                const Text('DONAPOS ERP v1.6', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.w900, fontSize: 9)),
                                const SizedBox(height: 16),
                                const DonaposFooter(),
                                const SizedBox(height: 16),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                       AppConfig.isTrainingMode = !AppConfig.isTrainingMode;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(AppConfig.isTrainingMode ? 'MODE LATIHAN AKTIF (DATA TIDAK DISIMPAN)' : 'MODE NORMAL'),
                                        backgroundColor: AppConfig.isTrainingMode ? Colors.orange : Colors.green,
                                      )
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppConfig.isTrainingMode ? Colors.orange : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white12)
                                    ),
                                    child: Text(
                                      AppConfig.isTrainingMode ? 'TRAINING MODE ON' : 'Training Mode Off',
                                      style: TextStyle(
                                        color: AppConfig.isTrainingMode ? Colors.black : Colors.white24,
                                        fontSize: 9, fontWeight: FontWeight.bold
                                      )
                                    ),
                                  ),
                                )
                            ],
                        ),
                      )
                  ],
              ),
          )
      );
  }

  Widget _buildQrItem(String label, String url, {double size = 100}) {
      return Column(
          children: [
              InkWell(
                  onTap: () {
                      showDialog(
                          context: context, 
                          builder: (ctx) => AlertDialog(
                              title: const Text("BUKA WEBSITE?"),
                              content: Text("Apakah Anda ingin membuka halaman $label?\n($url)"),
                              actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BATAL", style: TextStyle(color: Colors.grey))),
                                  TextButton(
                                      onPressed: () {
                                          Navigator.pop(ctx);
                                          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                      }, 
                                      child: const Text("YA, BUKA", style: TextStyle(fontWeight: FontWeight.bold))
                                  ),
                              ],
                          )
                      );
                  },
                  child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.white,
                      child: QrImageView(
                          data: url,
                          version: QrVersions.auto,
                          size: size,
                          backgroundColor: Colors.white,
                      ),
                  ),
              ),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.sp)),
          ],
      );
  }
  
  Widget _buildUserSelectScreen(LanguageProvider lp) {
      final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
      return Scaffold(
          backgroundColor: MetroColors.background,
          body: Row(
              children: [
                  Container(
                      width: isLandscape ? 300.sc : 80.sc,
                      color: MetroColors.primary,
                      padding: EdgeInsets.all(24.sc),
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  // _buildLanguageSwitch(), // Removed
                                  SizedBox(height: 24.sc),
                                  Icon(Icons.person_pin, size: 48.sc, color: Colors.white),
                                  if (isLandscape) ...[
                                      SizedBox(height: 24.sc),
                                      Text('DonaPOS', style: TextStyle(fontSize: 28.8.sp, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5.sc)),
                                      
                                      _buildSystemInfo(lp),

                                      SizedBox(height: 32.sc),
                                      const DonaposFooter(),
                                      SizedBox(height: 32.sc),
                                  ]
                              ],
                          ),
                      ),
                  ),
                  Expanded(
                      child: Container(
                          padding: EdgeInsets.all(isLandscape ? 32.sc : 16.sc),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  MetroSectionTitle(title: lp.translate('login_as_staff')),
                                  Text(lp.translate('choose_your_username'), style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: MetroColors.text, letterSpacing: -1.sc)),
                                  SizedBox(height: 8.sc),
                                  // Banner untuk user yang baru selesai aktivasi
                                  if (_isFirstTimeLogin)
                                    Container(
                                      padding: EdgeInsets.all(12.sc),
                                      margin: EdgeInsets.only(bottom: 12.sc),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                                        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
                                        borderRadius: BorderRadius.circular(8.sc),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_circle_rounded, color: const Color(0xFF4CAF50), size: 24.sc),
                                          SizedBox(width: 12.sc),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('PERANGKAT SIAP!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.sp, color: const Color(0xFF2E7D32), letterSpacing: 1.sc)),
                                                SizedBox(height: 2.sc),
                                                Text(
                                                  'Pilih nama Anda di bawah, lalu masukkan PIN dari admin.',
                                                  style: MetroTypography.body.copyWith(color: Colors.black54, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  SizedBox(height: 16.sc),
                                  Expanded(
                                      child: Builder(
                                        builder: (context) {
                                          final filteredUsers = _users.where((u) => u.pin != null && u.pin!.isNotEmpty).toList();
                                          
                                          if (filteredUsers.isEmpty) {
                                            return Center(child: Text(lp.translate('staff_data_empty'), style: TextStyle(color: Colors.black12, fontWeight: FontWeight.w900, letterSpacing: 2.sc)));
                                          }
                                          
                                          return GridView.builder(
                                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: isLandscape ? 4 : 2, 
                                                  crossAxisSpacing: 12.sc,
                                                  mainAxisSpacing: 12.sc,
                                                  childAspectRatio: 0.85,
                                              ),
                                              itemCount: filteredUsers.length,
                                              itemBuilder: (ctx, index) {
                                                final user = filteredUsers[index];
                                                return MetroTile(
                                                  label: user.firstName,
                                                  subLabel: '@${user.username}',
                                                  icon: Icons.person,
                                                  color: MetroColors.productColors[index % MetroColors.productColors.length],
                                                  onTap: () => setState(() {
                                                      _selectedUser = user;
                                                      if (_isDemoMode) _pinController.text = '12345';
                                                  }),
                                                );
                                              },
                                          );
                                        }
                                      ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                      alignment: Alignment.centerRight,
                                      child: MetroButton(
                                          label: lp.translate('logout_exit'), 
                                          icon: Icons.logout,
                                          isSecondary: true, 
                                          color: MetroColors.error,
                                          onPressed: () => setState(() => _isSetupMode = true)
                                      ),
                                  )
                              ],
                          ),
                      )
                  )
              ],
          ),
      );
  }
  
  Widget _buildPinScreen(LanguageProvider lp) {
      void onKeyTap(String value) {
        setState(() {
          if (value == 'BACK') {
              if (_pinController.text.isNotEmpty) {
                  _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1);
              }
          } else if (value == 'ENTER') {
              _pinLogin();
          } else {
              if (_pinController.text.length < 6) _pinController.text += value;
              if (_pinController.text.length == 6) {
                // Auto login on 6 digits if desired, or let user press ENTER
              }
          }
        });
      }
      final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

      return Scaffold(
          backgroundColor: MetroColors.background,
          body: Stack(
            children: [
              KeyboardListener(
                  focusNode: _pinFocusNode,
                  autofocus: true,
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent) {
                      final key = event.logicalKey;
                      if (key == LogicalKeyboardKey.backspace) {
                        onKeyTap('BACK');
                      } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
                        onKeyTap('ENTER');
                      } else {
                        final label = event.logicalKey.keyLabel;
                        if (RegExp(r'^[0-9]$').hasMatch(label)) {
                          onKeyTap(label);
                        }
                      }
                    }
                  },
                  child: Flex(
                      direction: isLandscape ? Axis.horizontal : Axis.vertical,
                      children: [
                          Expanded(
                              flex: isLandscape ? 4 : 3,
                              child: Container(
                                  color: MetroColors.primary,
                                  height: double.infinity,
                                  width: double.infinity,
                                  child: Center(
                                      child: SingleChildScrollView(
                                        child: Padding(
                                            padding: const EdgeInsets.all(48),
                                            child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                    const SizedBox(height: 32),
                                                     Text(
                                                       _isFirstTimeLogin ? 'PERTAMA KALI MASUK' : 'AUTHENTICATION',
                                                       style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _isFirstTimeLogin ? Colors.amber : Colors.white70, letterSpacing: 2),
                                                     ),
                                                    const SizedBox(height: 8),
                                                    Text(_isFirstTimeLogin ? 'HALO,' : lp.translate('welcome_back'), style: const TextStyle(fontSize: 21.6, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
                                                    Text(_selectedUser!.firstName.toUpperCase(), style: const TextStyle(fontSize: 43.2, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                                                    const SizedBox(height: 32),
                                                    // Info PIN yang JELAS
                                                    Container(
                                                      padding: const EdgeInsets.all(16),
                                                      decoration: BoxDecoration(
                                                        color: _isFirstTimeLogin ? Colors.amber.withOpacity(0.15) : Colors.white.withOpacity(0.08),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: _isFirstTimeLogin ? Colors.amber.withOpacity(0.4) : Colors.white12),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Icon(_isFirstTimeLogin ? Icons.info_rounded : Icons.vpn_key_rounded, color: _isFirstTimeLogin ? Colors.amber : Colors.white54, size: 18),
                                                              const SizedBox(width: 8),
                                                              Text(
                                                                _isFirstTimeLogin ? 'CARA MENDAPATKAN PIN' : 'MASUKKAN PIN ANDA',
                                                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: _isFirstTimeLogin ? Colors.amber : Colors.white70, letterSpacing: 1),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 8),
                                                          Text(
                                                            _isFirstTimeLogin
                                                              ? '• PIN diatur oleh Admin / Pemilik Bisnis\n• Hubungi admin Anda untuk mendapatkan PIN\n• PIN biasanya 4-6 digit angka'
                                                              : lp.translate('enter_pin_staff'),
                                                            style: TextStyle(color: _isFirstTimeLogin ? Colors.white.withOpacity(0.85) : Colors.white38, fontSize: 10, fontWeight: FontWeight.w600, height: 1.6),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 32),
                                                    MetroButton(
                                                      label: lp.translate('back_to_user_list'), 
                                                      isSecondary: true, 
                                                      color: Colors.white.withOpacity(0.1),
                                                      onPressed: () => setState(() { _selectedUser = null; _pinController.clear(); })
                                                    ),
                                                    const SizedBox(height: 48),
                                                    const DonaposFooter(),
                                                ],
                                            ),
                                        ),
                                      ),
                                  ),
                              )
                          ),
                          Expanded(
                              flex: isLandscape ? 6 : 7,
                              child: Container(
                                  height: double.infinity,
                                  width: double.infinity,
                                  child: Center(
                                    child: SingleChildScrollView(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: isLandscape ? 48 : 32,
                                            vertical: isLandscape ? 16 : 32
                                        ),
                                        child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                        Text(
                                          lp.translate('input_pin_security'),
                                          style: MetroTypography.inputLabel.copyWith(color: Colors.black26, fontWeight: FontWeight.w900),
                                        ),
                                        SizedBox(height: isLandscape ? 24 : 48),
                                        // PIN Indicators (SOLID METRO STYLE)
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: List.generate(6, (index) {
                                            bool isActive = _pinController.text.length > index;
                                            return AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              width: 35, height: 35,
                                              margin: const EdgeInsets.symmetric(horizontal: 4),
                                              decoration: BoxDecoration(
                                                color: isActive ? MetroColors.secondary : Colors.white,
                                                border: Border.all(
                                                  color: isActive ? MetroColors.secondary : Colors.black.withOpacity(0.1), 
                                                  width: 2
                                                ),
                                                boxShadow: isActive ? [
                                                  BoxShadow(color: MetroColors.secondary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                                                ] : null,
                                              ),
                                              child: Center(
                                                child: isActive 
                                                  ? const Icon(Icons.circle, size: 12, color: Colors.white)
                                                  : null,
                                              ),
                                            );
                                          }),
                                        ),
                                        SizedBox(height: isLandscape ? 16 : 48),
                                        _buildNumpad(onKeyTap),
                                    ],
                                ),
                              ),
                            ),
                          ),
                        ),
                          ),
                      ],
                  ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(child: DonaposLoader(size: 60)),
                )
            ],
          ),
      );
  }

  Widget _buildNumpad(Function(String) onTap) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          children: [
               _numpadRow(['1','2','3'], onTap),
               const SizedBox(height: 12),
               _numpadRow(['4','5','6'], onTap),
               const SizedBox(height: 12),
               _numpadRow(['7','8','9'], onTap),
               const SizedBox(height: 12),
               _numpadRow(['BACK','0','ENTER'], onTap),
          ]
        ),
      );
  }

  Widget _numpadRow(List<String> keys, Function(String) onTap) {
      return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: keys.map((e) => _numBtn(e, onTap)).toList(),
      );
  }
  
  Widget _numBtn(String label, Function(String) onTap, {Color? color}) {
      final isAction = label == 'BACK' || label == 'ENTER';
      final isBack = label == 'BACK';
      
      final btnColor = isAction 
          ? (isBack ? MetroColors.error : MetroColors.retailPrimary)
          : Colors.white;

      return Container(
          width: 64, height: 64,
          margin: const EdgeInsets.all(4),
          child: Material(
              shape: const CircleBorder(),
              color: btnColor,
              elevation: isAction ? 8 : 2,
              shadowColor: btnColor.withOpacity(0.4),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                  onTap: () {
                      debugPrint('PIN Button Clicked: $label');
                      onTap(label);
                  },
                  child: Center(
                      child: isAction 
                          ? Icon(
                              isBack ? Icons.backspace_outlined : Icons.check, 
                              color: Colors.white, size: 28
                            )
                          : Text(label, style: const TextStyle(fontSize: 25, color: MetroColors.text, fontWeight: FontWeight.w600)),
                  ),
              ),
          ),
      );
  }

  Widget _buildSystemInfo(LanguageProvider lp) {
    if (_systemStatus.isEmpty) return const SizedBox();
    
    final products = _systemStatus['products'] ?? 0;
    final categories = _systemStatus['categories'] ?? 0;
    final tables = _systemStatus['tables'] ?? 0;
    final discounts = _systemStatus['discounts'] ?? 0;
    final lastTx = _systemStatus['last_transaction'];
    
    String lastUser = 'N/A';
    String lastTotal = 'Rp 0';
    String lastDateTime = lp.currentLanguage == AppLanguage.id ? 'BELUM ADA TRANSAKSI' : 'NO TRANSACTIONS YET';
    
    if (lastTx != null) {
        lastUser = lastTx['cashier_name'] ?? 'KASIR';
        final date = (lastTx['created_at'] ?? '').toString().split(' ')[0];
        final timeFull = (lastTx['created_at'] ?? '').toString().contains(' ') ? (lastTx['created_at'] ?? '').toString().split(' ')[1] : '00:00';
        final time = timeFull.length >= 5 ? timeFull.substring(0, 5) : timeFull;
        lastTotal = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(lastTx['total']);
        lastDateTime = '$date $time';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // BOX 1: BUSINESS INFO
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_businessName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13, letterSpacing: 1)),
              Text(_locationName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // BOX 2: STATUS SISTEM
        Text(lp.translate('system_status'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.sp)),
        const SizedBox(height: 8),
        _statusLine('• ${lp.translate('product_count')}= $products'),
        _statusLine('• ${lp.translate('category_count')}= $categories'),
        _statusLine('• ${lp.translate('table_count')}= $tables'),
        _statusLine('• ${lp.translate('discount')}= ${discounts > 0 ? lp.translate('has_discount') : lp.translate('no_discount')}'),
        
        const SizedBox(height: 24),
        
        // BOX 3: STATUS TRANSAKSI
        Text(lp.translate('transaction_status'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13.sp)),
        const SizedBox(height: 8),
        _statusLine('• $lastUser'),
        _statusLine('• TOTAL $lastTotal'),
        _statusLine('• $lastDateTime'),
        const SizedBox(height: 8),
        _statusLine(lp.translate('not_closed_yet'), color: Colors.redAccent),
      ],
    );
  }

  Widget _statusLine(String text, {Color color = Colors.white70}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(text, style: MetroTypography.caption.copyWith(color: color, fontWeight: FontWeight.bold, height: 1.4)),
    );
  }
}
