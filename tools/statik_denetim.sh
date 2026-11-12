#!/usr/bin/env bash
# GDScript uyarılarını hataya çevirip bütün betikleri derler:  bash tools/statik_denetim.sh
# Her betikte ilk uyarı yazılır; düzeltip yeniden çalıştırın. Temizse "0 sorunlu" yazar.
set -e
cd "$(dirname "$0")/.."
G="${GODOT:-/c/Users/pc/Godot/4.3/Godot_v4.3-stable_win64_console.exe}"
{
  echo "[debug]"
  for u in unassigned_variable unassigned_variable_op_assign unused_variable unused_local_constant \
           unused_private_class_variable unused_parameter unused_signal shadowed_variable \
           shadowed_variable_base_class shadowed_global_identifier unreachable_code unreachable_pattern \
           standalone_expression standalone_ternary incompatible_ternary static_called_on_instance \
           redundant_await assert_always_true assert_always_false integer_division narrowing_conversion \
           int_as_enum_without_cast int_as_enum_without_match confusable_identifier \
           confusable_local_declaration confusable_local_usage confusable_capture_reassignment \
           empty_file deprecated_keyword native_method_override get_node_default_without_onready; do
    echo "gdscript/warnings/$u=2"
  done
} > override.cfg
trap 'rm -f override.cfg' EXIT
timeout 120 "$G" --headless --path . res://tools/StatikDenetim.tscn 2>&1 | python tools/statik_ozet.py
