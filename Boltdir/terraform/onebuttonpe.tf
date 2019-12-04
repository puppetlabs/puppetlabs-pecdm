# GCP Project ID
variable "project"            { }
# Domain name assigned to DNS zone
variable "dns_domain"         { }
# Name of of the actual zone in GCP CloudDNS
variable "dns_zone"           { }
# Shared user name across instances
variable "user"               { }
# Location on disk of the SSH key ot use for Linux access
variable "ssh_key"            { default = "~/.ssh/id_rsa.pub" }
# GCP region for the deployment
variable "region"             { default = "us-west1" }
# GCP zone for the deployment
variable "zones"               { default = [ "us-west1-a", "us-west1-b", "us-west1-c" ] }
# Number of forwarders to deploy, number is actually doubled because it deploys both Linux AND Windows
variable "compiler_count"    { default = 3 }
# The image deploy Linux from
variable "linux_image"        { default = "centos-cloud/centos-7" }
# Permitted IP subnets, make this more open if required and single IP adresses should be defined as a /32
variable "firewall_permitted" { default = [ "10.128.0.0/9" ] }
# A static ID for the deployment that can be used to group together multiple deployments of the test drive
variable "deployment_id"      { default = "0" }

provider "google" {
  project = var.project
  region  = var.region
}

# To contain each PE deployment, a fresh VPC to deploy into
resource "google_compute_network" "pe" {
  name = "pe-${var.deployment_id}"
  auto_create_subnetworks = false
}

# Manual creation of subnets works better when instances are dependent on their
# existance, allowing GCP to create them automatically creates a race condition.
resource "google_compute_subnetwork" "pe_west" {
  name          = "pe-${var.deployment_id}"
  ip_cidr_range = "10.138.0.0/20"
  network       = "${google_compute_network.pe.self_link}"
}

# Instances should not be accessible by the open internet so a fresh VPC should
# be restricted to organization allowed subnets
resource "google_compute_firewall" "pe_default" {
  name    = "pe-default-${var.deployment_id}"
  network = "${google_compute_network.pe.self_link}"
  priority = 1000
  source_ranges = var.firewall_permitted
  allow { protocol = "icmp" }
  allow { protocol = "tcp" }
  allow { protocol = "udp" }
}

# Create a friendly DNS name for accessing the new PE environment
resource "google_dns_record_set" "pe" {
  name = "pe-${var.deployment_id}.${var.dns_domain}."
  type = "A"
  ttl  = 1

  managed_zone = var.dns_zone

  rrdatas = ["${google_compute_instance.master[0].network_interface[0].access_config[0].nat_ip}"]
}

# Create a friendly DNS name for accessing the new PE environment
resource "google_dns_record_set" "compilers" {
  name = "pe-compilers-${var.deployment_id}.${var.dns_domain}."
  type = "A"
  ttl  = 1

  managed_zone = var.dns_zone

  rrdatas = ["${google_compute_forwarding_rule.pe_compiler_lb.ip_address}"]
}

# Instances to run PE MOM
resource "google_compute_instance" "master" {
  name         = "pe-master-${var.deployment_id}-${count.index}"
  machine_type = "n1-standard-4"
  count        = 2
  zone         = element(var.zones, count.index)

  metadata = {
    "sshKeys" = "${var.user}:${file(var.ssh_key)}"
    "VmDnsSetting" = "ZonalPreferred"
  }

  boot_disk {
    initialize_params {
      image = var.linux_image
      size  = 50
      type  = "pd-ssd"
    }
  }

  network_interface {
    network = google_compute_network.pe.self_link
    subnetwork = google_compute_subnetwork.pe_west.self_link
    access_config { }
  }

  # Using remote-execs on each instance deployemnt to ensure thing are really
  # really up before doing the next steps, helps with development tasks that
  # immediately attempt to leverage Bolt
  provisioner "remote-exec" {
    connection {
      host = self.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = var.user
    }
    inline = ["# Connected"]
  }
}

# Instances to run PE PSQL
resource "google_compute_instance" "psql" {
  name         = "pe-psql-${var.deployment_id}-${count.index}"
  machine_type = "n1-standard-8"
  count        = 2
  zone         = element(var.zones, count.index)

  metadata = {
    "sshKeys" = "${var.user}:${file(var.ssh_key)}"
    "VmDnsSetting" = "ZonalPreferred"
  }

  boot_disk {
    initialize_params {
      image = var.linux_image
      size  = 100
      type  = "pd-ssd"
    }
  }

  network_interface {
    network = google_compute_network.pe.self_link
    subnetwork = google_compute_subnetwork.pe_west.self_link
    access_config { }
  }

  # Using remote-execs on each instance deployemnt to ensure thing are really
  # really up before doing the next steps, helps with development tasks that
  # immediately attempt to leverage Bolt
  provisioner "remote-exec" {
    connection {
      host = self.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = var.user
    }
    inline = ["# Connected"]
  }
}

# Instances to run a compilers
resource "google_compute_instance" "compiler" {
  name         = "pe-complier-${var.deployment_id}-${count.index}"
  machine_type = "n1-standard-2"
  count        = var.compiler_count
  zone         = element(var.zones, count.index)

  metadata = {
    "sshKeys" = "${var.user}:${file(var.ssh_key)}"
    "VmDnsSetting" = "ZonalPreferred"
  }

  boot_disk {
    initialize_params {
      image = var.linux_image
      size  = 15
      type  = "pd-ssd"
    }
  }

  network_interface {
    network = google_compute_network.pe.self_link
    subnetwork = google_compute_subnetwork.pe_west.self_link
    access_config { }
  }

  # Using remote-execs on each instance deployemnt to ensure thing are really
  # really up before doing the next steps, helps with development tasks that
  # immediately attempt to leverage Bolt
  provisioner "remote-exec" {
    connection {
      host = self.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = var.user
    }
    inline = ["# Connected"]
  }
}

resource "google_compute_instance_group" "a" {
  name        = "pe-complier-${var.deployment_id}-zone-a"

  instances = [for i in google_compute_instance.compiler[*] : i.self_link if i.zone == "${var.region}-a"]
  zone = "${var.region}-a"
}

resource "google_compute_instance_group" "b" {
  name        = "pe-complier-${var.deployment_id}-zone-b"

  instances = [for i in google_compute_instance.compiler[*] : i.self_link if i.zone == "${var.region}-b"]
  zone = "${var.region}-b"
}

resource "google_compute_instance_group" "c" {
  name        = "pe-complier-${var.deployment_id}-zone-c"

  instances = [for i in google_compute_instance.compiler[*] : i.self_link if i.zone == "${var.region}-c"]
  zone = "${var.region}-c"
}

resource "google_compute_health_check" "pe_compiler" {
  name = "pe-compiler-${var.deployment_id}"

  tcp_health_check { port = "8140" }
}

resource "google_compute_region_backend_service" "pe_compiler_lb" {
  name          = "pe-compiler-lb-${var.deployment_id}"
  health_checks = [google_compute_health_check.pe_compiler.self_link]
  region        = var.region

  backend { group = google_compute_instance_group.a.self_link } 
  backend { group = google_compute_instance_group.b.self_link }
  backend { group = google_compute_instance_group.c.self_link }
}

resource "google_compute_forwarding_rule" "pe_compiler_lb" {
  name                  = "pe-compiler-lb-${var.deployment_id}"
  load_balancing_scheme = "INTERNAL"
  ports                 = ["8140","8142"]
  network               = google_compute_network.pe.self_link
  subnetwork            = google_compute_subnetwork.pe_west.self_link
  backend_service       = google_compute_region_backend_service.pe_compiler_lb.self_link
}


# Convient log message at end of Terraform apply to inform you where your
# Splunk instance can be accessed.
output "fqdn" {
  value       = google_dns_record_set.pe.name
  description = "The FQDN of a new Pupept Enterprise console"
}
