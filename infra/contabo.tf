locals {
  # Install-time only: Talos upgrades itself afterwards (task talos:sync), so this is
  # intentionally not tracked by Renovate. Same schematic as talconfig.yaml.
  talos_schematic = "376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
  talos_version   = "v1.14.5"
}

resource "contabo_image" "talos" {
  name        = "talos-${local.talos_version}"
  description = "Talos ${local.talos_version} (schematic ${substr(local.talos_schematic, 0, 12)})"
  image_url   = "https://factory.talos.dev/image/${local.talos_schematic}/${local.talos_version}/nocloud-amd64.qcow2"
  os_type     = "Linux"
  version     = local.talos_version
}

# Boots Talos in maintenance mode; the machine config is applied with
# `task bootstrap:talos` (talosctl apply-config --insecure), so no Talos secrets end up in state.
resource "contabo_instance" "kmaster1" {
  display_name = "kmaster1"
  product_id   = var.contabo_product_id
  region       = var.contabo_region
  period       = var.contabo_period
  image_id     = contabo_image.talos.id

  lifecycle {
    prevent_destroy = true
    # Changing image_id reinstalls the server and wipes the node.
    ignore_changes = [image_id]
  }
}
