# GCP Project ID
variable "project"        { }
# Shared user name across instances
variable "user"           { }
# Location on disk of the SSH key to use for system access
variable "ssh_key"        { default = "~/.ssh/id_rsa.pub" }
# GCP region for the deployment
variable "region"         { default = "us-west1" }
# GCP zones for the deployment
variable "zones"          { default = [ "us-west1-a", "us-west1-b", "us-west1-c" ] }
# Number of compilers to deploy, will be spread across all defined zones
variable "compiler_count" { default = 3 }
# The instance image to deploy from
variable "instance_image"    { default = "centos-cloud/centos-7" }
# Permitted IP subnets, default is internal only, single IP adresses should be defined as /32
variable "firewall_allow" { default = [ "10.128.0.0/9" ] }

provider "google" {
  project = var.project
  region  = var.region
}

# It is intended that multiple deployments can be launched easily without
# name colliding
resource "random_id" "deployment" {
  byte_length = 3
}

# Contain all the networking configuration in a module for readability
module "networking" {
  source = "./modules/networking"
  id     = random_id.deployment.hex
  allow  = var.firewall_allow
}

# Contain all the loadbalancer configuration in a module for readability
module "loadbalancer" {
  source     = "./modules/loadbalancer"
  id         = random_id.deployment.hex
  ports      = ["8140", "8142"]
  network    = module.networking.network_link
  subnetwork = module.networking.subnetwork_link
  region     = var.region
  zones      = var.zones
  instances  = google_compute_instance.compiler[*]
}

# Instances to run PE MOM
resource "google_compute_instance" "master" {
  name         = "pe-master-${random_id.deployment.hex}-${count.index}"
  machine_type = "e2-standard-4"
  count        = 2
  zone         = element(var.zones, count.index)

  # Old style internal DNS easiest until Bolt inventory dynamic
  metadata = {
    "sshKeys" = "${var.user}:${file(var.ssh_key)}"
    "VmDnsSetting" = "ZonalPreferred"
  }

  boot_disk {
    initialize_params {
      image = var.instance_image
      size  = 50
      type  = "pd-ssd"
    }
  }

  network_interface {
    network = module.networking.network_link
    subnetwork = module.networking.subnetwork_link
    access_config { }
  }

  # Using remote-execs on each instance deployemnt to ensure things are really
  # really up before doing to the next step, helps with Bolt plans that'll
  # immediately connect then fail
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
  name         = "pe-psql-${random_id.deployment.hex}-${count.index}"
  machine_type = "e2-standard-8"
  count        = 2
  zone         = element(var.zones, count.index)

  # Old style internal DNS easiest until Bolt inventory dynamic
  metadata = {
    "sshKeys" = "${var.user}:${file(var.ssh_key)}"
    "VmDnsSetting" = "ZonalPreferred"
  }

  boot_disk {
    initialize_params {
      image = var.instance_image
      size  = 100
      type  = "pd-ssd"
    }
  }

  network_interface {
    network = module.networking.network_link
    subnetwork = module.networking.subnetwork_link
    access_config { }
  }

  # Using remote-execs on each instance deployemnt to ensure things are really
  # really up before doing to the next step, helps with Bolt plans that'll
  # immediately connect then fail
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
  name         = "pe-compiler-${random_id.deployment.hex}-${count.index}"
  machine_type = "e2-standard-2"
  count        = var.compiler_count
  zone         = element(var.zones, count.index)

  # Old style internal DNS easiest until Bolt inventory dynamic
  metadata = {
    "sshKeys" = "${var.user}:${file(var.ssh_key)}"
    "VmDnsSetting" = "ZonalPreferred"
  }

  boot_disk {
    initialize_params {
      image = var.instance_image
      size  = 15
      type  = "pd-ssd"
    }
  }

  network_interface {
    network = module.networking.network_link
    subnetwork = module.networking.subnetwork_link
    access_config { }
  }

  # Using remote-execs on each instance deployemnt to ensure things are really
  # really up before doing to the next step, helps with Bolt plans that'll
  # immediately connect then fail
  provisioner "remote-exec" {
    connection {
      host = self.network_interface[0].access_config[0].nat_ip
      type = "ssh"
      user = var.user
    }
    inline = ["# Connected"]
  }
}

# Output data used by Bolt to do further work, doing this allows for a clean
# and abstracted interface between cloud provider implementation
output "console" {
  value       = google_compute_instance.master[0].network_interface[0].access_config[0].nat_ip
  description = "The external IP address of the Pupept Enterprise console"
}
output "pool" {
  value       = module.loadbalancer.lb_dns_name
  description = "The internal FQDN of the Pupept Enterprise compiler pool"
}
output "infrastructure" {
  value = { 
    masters   : [for i in google_compute_instance.master[*]   : [ "${i.name}.${i.zone}.c.${i.project}.internal", i.network_interface[0].access_config[0].nat_ip] ], 
    psql      : [for i in google_compute_instance.psql[*]     : [ "${i.name}.${i.zone}.c.${i.project}.internal", i.network_interface[0].access_config[0].nat_ip] ], 
    compilers : [for i in google_compute_instance.compiler[*] : [ "${i.name}.${i.zone}.c.${i.project}.internal", i.network_interface[0].access_config[0].nat_ip] ] 
  }
  description = "A collection of internal DNS names and IP addresses of PE infrastructure components"
}
