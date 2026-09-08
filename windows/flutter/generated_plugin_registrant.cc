//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <firebase_core/firebase_core_plugin_c_api.h>
#include <flutter_ble_peripheral/flutter_ble_peripheral_plugin_c_api.h>
#include <geolocator_windows/geolocator_windows.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FirebaseCorePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FirebaseCorePluginCApi"));
  FlutterBlePeripheralPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterBlePeripheralPluginCApi"));
  GeolocatorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("GeolocatorWindows"));
}
