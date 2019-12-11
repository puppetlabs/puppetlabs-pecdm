output "lb_ip" {
  value       = google_compute_forwarding_rule.pe_compiler_lb.ip_address
  description = "The IP of a new Pupept Enterprise compiler LB"
}