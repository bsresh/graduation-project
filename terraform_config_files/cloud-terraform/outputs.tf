
output "bastion_public_ip" {
	description = "nat_ip_address"
	value       = yandex_compute_instance.vm-bastion-host.network_interface[0].nat_ip_address
}

output "bastion_fqdn" {
	description = "bastion_fqdn"
	value       = yandex_compute_instance.vm-bastion-host.fqdn
}

output "fqdn1" {
	description = "fqdn"
	value       = yandex_compute_instance_group.alb-vm-group.instances[0].fqdn
}


output "fqdn2" {
	description = "fqdn"
	value       = yandex_compute_instance_group.alb-vm-group.instances[1].fqdn
}

output "zabbix_public_ip" {
	description = "nat_ip_address"
	value       = yandex_compute_instance.vm-zabbix.network_interface[0].nat_ip_address
}

output "zabbix-fqdn" {
	description = "fqdn-zabbix"
	value       = yandex_compute_instance.vm-zabbix.fqdn
}

