////////////////////////////////////////////////////////////////////////////////////////
//                                        VARIABLES
////////////////////////////////////////////////////////////////////////////////////////
variable "linode_extra_authorized_keys" {
  type    = list(string)
  default = []
}

variable "linode_regions" {
  type = list(string)
  default = [
    # "ca-central",
    # "us-iad",
    # "us-ord",
    # "fr-par",
    # "us-sea",
    # "nl-ams",
    # "se-sto",
    # "es-mad",
    # "in-maa",
    # "jp-osa",
    # "it-mil",
    # "us-mia",
    # "id-cgk",
    # "us-lax",
    # "au-mel",
    # "in-bom-2",
    # "de-fra-2",
    # "sg-sin-2",
    # "jp-tyo-3",
    # "us-central",
    # "us-east",
    # "ap-south",
    # "gb-lon",
    # "ap-southeast",
    "us-southeast",
    "eu-central",
    "ap-northeast",
    "br-gru",
    "eu-west",
    "us-west",
    "ap-west",
  ]
}

variable "linode_instance_type" {
  type    = string
  default = "g6-standard-8"
}

variable "linode_instance_additional_tags" {
  type    = list(string)
  default = []
}

////////////////////////////////////////////////////////////////////////////////////////
//                                        LOCALS
////////////////////////////////////////////////////////////////////////////////////////
locals {
  linode_instance_image = "linode/ubuntu24.04"
  linode_default_region = "us-southeast"
  linode_default_authorized_keys = [
    # Core DevOps SSH Key
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCtYV6USErtJLWhgvOxhK01mNYOGg8vBJDyeaGv6g7LGLgWChNpyEvLqM0NNwU1f/4Lsu1owOBODsEwaUWSbpSCN1u6QNnM/YlNBR2N1MWERTY4HWdhJ1cTNXbVqkJfeB6mCKNfmrb/ndjzb4ZIM3v/OA/EXddN5JsFmNaZ3bMYcWUbYqfn8tFmYtzLtc1e+mRwvWF7PY4N6SKMm6eT74OSLiR8Jg6DQxvkimOFlFDqjF/e4P6wsVkLZNypgAfGiBpJld2QK5RQF/8/wy3Y1iakPjusQe2Fy9jA5fiZRomvPN/2sIjlZ98loDPIxZhLhfn2s1mlkCP+txCCSiXMGx/CL5hb25SJVGluj6yH9WuhbGdOjPthWE3RfnJXjqjq/SvXpE96M4Mraa9lurc2mkDgS3ahO6izgBLw3AZyOq3kBaxl+29BUdzOl7SOiygTovyZIcVdDtIJ0Gnf1+fD9YlCy9ucLB2QruoMT80Ctxn1oweBd3Z1CHEjxpjPisEOLazBscNeTqsyRNJ0cVojPIc9LWHbKHhmtkI8k66ONAHmA/jlheNfk0bIdjpcIMSWEKTTkxwx+aX3b9uyaI/Rq116DezCjYXOekbBSQvYyEuM9ed/a67QczUgg3j4EzBltCXs423SobGGsZU7XQtuQsM05snKoahD6qfxdyScWhniMw=="
  ]
  linode_base_tags = [
    "core",
    "nethermind-devnet",
    var.ethereum_network,
  ]
  linode_vm_groups = flatten([
    for vm_group in local.vm_groups : [
      for i in range(0, vm_group.count) : {
        group_name = "${vm_group.name}"
        id         = "${vm_group.name}-${i + 1}"
        vms = {
          "${i + 1}" = {
            label  = "${var.ethereum_network}-${vm_group.name}-${i + 1}"
            region = element(var.linode_regions, i % length(var.linode_regions))
            type   = var.linode_instance_type
            ipv6   = try(vm_group.ipv6, true)
            tags = concat(
              [
                "${vm_group.name}",
                "${vm_group.validator_start + ceil(i * (vm_group.validator_end - vm_group.validator_start) / vm_group.count)}",
                "${min(vm_group.validator_start + ceil((i + 1) * (vm_group.validator_end - vm_group.validator_start) / vm_group.count), vm_group.validator_end)}"
              ],
              local.linode_base_tags
            )
          }
        }
      }
    ]
  ])
  linode_vms = flatten([
    for group in local.linode_vm_groups : [
      for vm_key, vm in group.vms : {
        id        = "${group.id}"
        group_key = "${group.group_name}"
        vm_key    = vm_key

        label  = vm.label
        region = try(vm.region, try(group.region, local.linode_default_region))
        image  = local.linode_instance_image
        type   = vm.type
        tags   = vm.tags
        ipv6   = vm.ipv6
        authorized_keys = concat(
          local.linode_default_authorized_keys,
          var.linode_extra_authorized_keys
        )
      }
    ]
  ])
}

resource "linode_instance" "nodes" {
  for_each = {
    for vm in local.linode_vms : "${vm.label}" => vm
  }

  label           = each.value.label
  image           = each.value.image
  region          = each.value.region
  type            = each.value.type
  tags            = each.value.tags
  authorized_keys = each.value.authorized_keys
}

resource "linode_firewall" "firewall" {
  label = "${var.ethereum_network}-nodes-fw"
  tags  = local.linode_base_tags

  # SSH
  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4 = [
      "0.0.0.0/0"
    ]
    ipv6 = [
      "::/0"
    ]
  }

  # Nginx / Web
  inbound {
    label    = "allow-http"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "80, 443"
    ipv4 = [
      "0.0.0.0/0"
    ]
    ipv6 = [
      "::/0"
    ]
  }

  # Consensus layer p2p port
  inbound {
    label    = "allow-consensus-p2p-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "9000, 9001"
    ipv4 = [
      "0.0.0.0/0"
    ]
    ipv6 = [
      "::/0"
    ]
  }

  inbound {
    label    = "allow-consensus-p2p-tcp"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "9000, 9001"
    ipv4 = [
      "0.0.0.0/0"
    ]
    ipv6 = [
      "::/0"
    ]
  }

  # Execution layer p2p Port

  inbound {
    label    = "allow-execution-p2p-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "30303"
    ipv4 = [
      "0.0.0.0/0"
    ]
    ipv6 = [
      "::/0"
    ]
  }

  inbound {
    label    = "allow-execution-p2p-tcp"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "30303"
    ipv4 = [
      "0.0.0.0/0"
    ]
    ipv6 = [
      "::/0"
    ]
  }

  inbound_policy = "DROP"

  outbound_policy = "ACCEPT"

  linodes = [
    for node in linode_instance.nodes : node.id
  ]
}

////////////////////////////////////////////////////////////////////////////////////////
//                                   DNS NAMES
////////////////////////////////////////////////////////////////////////////////////////

data "cloudflare_zone" "default" {
  filter = {
    name = "nethermind.dev"
  }
}

resource "cloudflare_dns_record" "server_record_v4" {
  for_each = {
    for vm in local.linode_vms : "${vm.label}" => vm
  }
  zone_id = data.cloudflare_zone.default.zone_id
  name    = "${each.value.label}.${var.ethereum_network}"
  type    = "A"
  content = linode_instance.nodes[each.key].ip_address
  proxied = false
  ttl     = 120
}

# resource "cloudflare_dns_record" "server_record_v6" {
#   for_each = {
#     for vm in local.linode_vms : "${vm.label}" => vm if vm.ipv6
#   }
#   zone_id = data.cloudflare_zone.default.zone_id
#   name    = "${each.value.label}.${var.ethereum_network}"
#   type    = "AAAA"
#   content = linode_instance.nodes[each.key].ipv6
#   proxied = false
#   ttl     = 120
# }

resource "cloudflare_dns_record" "server_record_rpc_v4" {
  for_each = {
    for vm in local.linode_vms : "${vm.label}" => vm
  }
  zone_id = data.cloudflare_zone.default.zone_id
  name    = "rpc.${each.value.label}.${var.ethereum_network}"
  type    = "A"
  content = linode_instance.nodes[each.key].ip_address
  proxied = false
  ttl     = 120
}

# resource "cloudflare_dns_record" "server_record_rpc_v6" {
#   for_each = {
#     for vm in local.linode_vms : "${vm.label}" => vm if vm.ipv6
#   }
#   zone_id = data.cloudflare_zone.default.zone_id
#   name    = "rpc.${each.value.label}.${var.ethereum_network}"
#   type    = "AAAA"
#   content = linode_instance.nodes[each.key].ipv6
#   proxied = false
#   ttl     = 120
# }

resource "cloudflare_dns_record" "server_record_beacon_v4" {
  for_each = {
    for vm in local.linode_vms : "${vm.label}" => vm
  }
  zone_id = data.cloudflare_zone.default.zone_id
  name    = "bn.${each.value.label}.${var.ethereum_network}"
  type    = "A"
  content = linode_instance.nodes[each.key].ip_address
  proxied = false
  ttl     = 120
}

# resource "cloudflare_dns_record" "server_record_beacon_v6" {
#   for_each = {
#     for vm in local.linode_vms : "${vm.label}" => vm if vm.ipv6
#   }
#   zone_id = data.cloudflare_zone.default.zone_id
#   name    = "bn.${each.value.label}.${var.ethereum_network}"
#   type    = "AAAA"
#   content = linode_instance.nodes[each.key].ipv6
#   proxied = false
#   ttl     = 120
# }

////////////////////////////////////////////////////////////////////////////////////////
//                          GENERATED FILES AND OUTPUTS
////////////////////////////////////////////////////////////////////////////////////////

resource "local_file" "ansible_inventory" {
  content = templatefile("ansible_inventory.tmpl",
    {
      ethereum_network_name = "${var.ethereum_network}"
      groups = merge(
        { for group in local.linode_vm_groups : "${group.group_name}" => true... },
      )
      hosts = merge(
        {
          for key, server in linode_instance.nodes : "li.${key}" => {
            ip              = server.ip_address
            ipv6            = try(slipt("/", server.ipv6[0])[0], "none")
            group           = try(server.tags[0], "unknown")
            validator_start = try(tonumber(server.tags[1]), 0)
            validator_end   = try(tonumber(server.tags[2]), 0) # if the tag is not a number it will be 0 - e.g no validator keys
            tags            = "${server.tags}"
            hostname        = "${split(".", key)[0]}"
            cloud           = "linode"
            region          = "${server.region}"
          }
        }
      )
    }
  )
  filename = "../../ansible/inventories/perfnet-1/inventory.yaml"
}
