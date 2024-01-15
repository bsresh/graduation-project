output "bastion_public_ip" {
	description = "nat_ip_address"
	value       = yandex_compute_instance.vm-bastion-host.network_interface[0].nat_ip_address
}

output "fqdn1" {
	description = "fqdn"
	value       = yandex_compute_instance_group.alb-vm-group.instances[0].fqdn
}

output "fqdn2" {
	description = "fqdn"
	value       = yandex_compute_instance_group.alb-vm-group.instances[1].fqdn
}
