/* Резервное копирование дисков ВМ /*


/***********snapshot-bastion***********************/

resource "yandex_compute_snapshot" "snapshot-bastion" {
  name           = "snapshot-bastion"
  source_disk_id = yandex_compute_instance.vm-bastion-host.boot_disk[0].disk_id
     depends_on = [
     yandex_compute_instance.vm-bastion-host,
     yandex_compute_snapshot_schedule.snapshot-schedule
     ]
}

data "yandex_compute_snapshot" "data-snapshot-bastion" {
  snapshot_id = yandex_compute_snapshot.snapshot-bastion.id
}

output "snapshot-bastion-host" {
  value = data.yandex_compute_snapshot.data-snapshot-bastion
}


/***********snapshot-zabbix***********************/

resource "yandex_compute_snapshot" "snapshot-zabbix" {
  name           = "snapshot-zabbix"
  source_disk_id = yandex_compute_instance.vm-zabbix.boot_disk[0].disk_id
  depends_on = [
  yandex_compute_instance.vm-zabbix,
  yandex_compute_snapshot_schedule.snapshot-schedule
  ]
}


data "yandex_compute_snapshot" "data-snapshot-zabbix" {
  snapshot_id = yandex_compute_snapshot.snapshot-zabbix.id
}

output "snapshot-zabbix" {
  value = data.yandex_compute_snapshot.data-snapshot-zabbix
}


/***********snapshot-elasticsearch***************/

resource "yandex_compute_snapshot" "snapshot-elasticsearch" {
  name           = "snapshot-elasticsearch"
  source_disk_id = yandex_compute_instance.vm-elasticsearch.boot_disk[0].disk_id
  depends_on = [
  yandex_compute_instance.vm-elasticsearch,
  yandex_compute_snapshot_schedule.snapshot-schedule
  ]
}


data "yandex_compute_snapshot" "data-snapshot-elasticsearch" {
  snapshot_id = yandex_compute_snapshot.snapshot-elasticsearch.id
}

output "snapshot-elasticsearch" {
  value = data.yandex_compute_snapshot.data-snapshot-elasticsearch
}


/***********snapshot-kibana***************/

resource "yandex_compute_snapshot" "snapshot-kibana" {
  name           = "snapshot-kibana"
  source_disk_id = yandex_compute_instance.vm-kibana.boot_disk[0].disk_id
  depends_on = [
  yandex_compute_instance.vm-kibana,
  yandex_compute_snapshot_schedule.snapshot-schedule
  ]
}


data "yandex_compute_snapshot" "data-snapshot-kibana" {
  snapshot_id = yandex_compute_snapshot.snapshot-kibana.id
}

output "snapshot-kibana" {
  value = data.yandex_compute_snapshot.data-snapshot-kibana
}



/***********snapshot-web-server-1***************/

resource "yandex_compute_snapshot" "snapshot-web-server-1" {
  name           = "snapshot-web-server-1"
  source_disk_id = yandex_compute_instance.web-server-1.boot_disk[0].disk_id
  depends_on = [
  yandex_compute_instance.web-server-1,
  yandex_compute_snapshot_schedule.snapshot-schedule
  ]
}

data "yandex_compute_snapshot" "data-snapshot-web-server-1" {
  snapshot_id = yandex_compute_snapshot.snapshot-web-server-1.id
}

output "snapshot-web-server-1" {
  value = data.yandex_compute_snapshot.data-snapshot-web-server-1
}


/***********snapshot-web-server-2***************/

resource "yandex_compute_snapshot" "snapshot-web-server-2" {
  name           = "snapshot-web-server-2"
  source_disk_id = yandex_compute_instance.web-server-2.boot_disk[0].disk_id
  depends_on = [
  yandex_compute_instance.web-server-2,
  yandex_compute_snapshot_schedule.snapshot-schedule
  ]
}

data "yandex_compute_snapshot" "data-snapshot-web-server-2" {
  snapshot_id = yandex_compute_snapshot.snapshot-web-server-2.id
}

output "snapshot-web-server-2" {
  value = data.yandex_compute_snapshot.data-snapshot-web-server-2
}
