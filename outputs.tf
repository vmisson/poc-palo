output "password" {
  description = "Firewall admin password"
  value       = random_password.this[0].result
  sensitive   = true
}
