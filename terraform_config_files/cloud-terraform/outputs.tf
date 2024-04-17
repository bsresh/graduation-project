output "bastion_public_ip" {
	description = "nat_ip_address"
	value       = yandex_compute_instance.vm-bastion-host.network_interface[0].nat_ip_address
}

output "bastion_fqdn" {
	description = "bastion_fqdn"
	value       = yandex_compute_instance.vm-bastion-host.fqdn
}

output "fqdn-web-server-1" {
	description = "fqdn-web-server-1"
	value       = yandex_compute_instance.web-server-1.fqdn
}

output "fqdn-web-server-2" {
	description = "fqdn-web-server-2"
	value       = yandex_compute_instance.web-server-2.fqdn
}

output "zabbix-fqdn" {
	description = "fqdn-zabbix"
	value       = yandex_compute_instance.vm-zabbix.fqdn
}

output "zabbix_private_ip" {
	description = "nat_ip_address"
	value       = yandex_compute_instance.vm-zabbix.network_interface[0].ip_address
}

output "elasticsearch-fqdn" {
	description = "fqdn-elasticsearch"
	value       = yandex_compute_instance.vm-elasticsearch.fqdn
}

output "kibana_private_ip" {
	description = "nat_ip_address"
	value       = yandex_compute_instance.vm-kibana.network_interface[0].ip_address
}

output "kibana-fqdn" {
	description = "fqdn-kibana"
	value       = yandex_compute_instance.vm-kibana.fqdn
}
