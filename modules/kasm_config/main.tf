locals {
  default_properties_yaml = replace(
    yamlencode(local.kasm_custom_default_properties),
    "/((?:^|\n)[\\s-]*)\"([\\w-]+)\":/",
    "$1$2:"
  )
}
