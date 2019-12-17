output "lb_dns_name" {
  value       = google_compute_forwarding_rule.pe_compiler_lb.service_name
  description = "The IP of a new Pupept Enterprise compiler LB"
}