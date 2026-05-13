//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <bluetooth_print_plus/bluetooth_print_plus_plugin.h>
#include <disk_space_2/disk_space_2_plugin.h>
#include <sqlite3_flutter_libs/sqlite3_flutter_libs_plugin.h>
#include <url_launcher_linux/url_launcher_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) bluetooth_print_plus_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "BluetoothPrintPlusPlugin");
  bluetooth_print_plus_plugin_register_with_registrar(bluetooth_print_plus_registrar);
  g_autoptr(FlPluginRegistrar) disk_space_2_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "DiskSpace_2Plugin");
  disk_space_2_plugin_register_with_registrar(disk_space_2_registrar);
  g_autoptr(FlPluginRegistrar) sqlite3_flutter_libs_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "Sqlite3FlutterLibsPlugin");
  sqlite3_flutter_libs_plugin_register_with_registrar(sqlite3_flutter_libs_registrar);
  g_autoptr(FlPluginRegistrar) url_launcher_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "UrlLauncherPlugin");
  url_launcher_plugin_register_with_registrar(url_launcher_linux_registrar);
}
