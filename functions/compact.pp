function autope::compact(
  Array $array,
) {
  $array.filter |$value| { $value != undef }
}
