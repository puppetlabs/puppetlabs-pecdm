output "network_link" {
  value = google_compute_network.pe.self_link
}

output "subnetwork_link" {
  value = google_compute_subnetwork.pe_west.self_link
}