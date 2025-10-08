//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <animated_item/animated_item_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) animated_item_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "AnimatedItemPlugin");
  animated_item_plugin_register_with_registrar(animated_item_registrar);
}
