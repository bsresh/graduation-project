# Локальные переменные

locals {
  ingress_site_v4_cidr_blocks = ["0.0.0.0/0"] # С каких ip-адресов доступен сайт
  ingress_ssh_v4_cidr_blocks = ["0.0.0.0/0"] # С каких ip-адресов разрешены входящие подключения по ssh
}

# Настройка провайдера

terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.47.0"
}

provider "yandex" {
  token     = var.iam_token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = "ru-central1-b"
}

# Создание сети

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}


# Создание NAT-шлюза

resource "yandex_vpc_gateway" "nat_gateway" {
  name = "nat-gateway"
  shared_egress_gateway {}
}


# Создание Таблицы маршрутизации

resource "yandex_vpc_route_table" "rt" {
  name       = "rt"
  network_id = yandex_vpc_network.network-1.id
  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
  depends_on     = [
    yandex_vpc_network.network-1,
    yandex_vpc_gateway.nat_gateway
    ]
}

# Создание подсетей

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet-1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["172.16.1.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
  depends_on     = [
    yandex_vpc_network.network-1,
    yandex_vpc_route_table.rt
    ]
}


resource "yandex_vpc_subnet" "subnet-2" {
  name           = "subnet-2"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["172.16.2.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
  depends_on     = [yandex_vpc_network.network-1,
                    yandex_vpc_route_table.rt
                   ]
}


/*Создание группы безопасности для бастионного хоста*/

resource "yandex_vpc_security_group" "sg-bastion-host" {
  name        = "sg-bastion-host"
  description = "This rule allows access to the bastion host from the internet"
  network_id  = yandex_vpc_network.network-1.id

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    v4_cidr_blocks = local.ingress_ssh_v4_cidr_blocks
    port           = 22
  }

  ingress {
    protocol       = "TCP"
    description    = "zabbix"
    v4_cidr_blocks = ["172.16.0.0/12"]
    port           = 10050
  }

  egress {
    protocol       = "ANY"
    description    = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 1
    to_port        = 65535
  }
  depends_on     = [yandex_vpc_network.network-1]
}

/*Создание группы безопасности для L7-балансировщика*/


resource "yandex_vpc_security_group" "alb-sg" {
  name       = "alb-sg"
  network_id = yandex_vpc_network.network-1.id

  egress {
    protocol       = "ANY"
    description    = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 1
    to_port        = 65535
  }

  ingress {
    protocol       = "TCP"
    description    = "ext-http"
    v4_cidr_blocks = local.ingress_site_v4_cidr_blocks
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "ext-https"
    v4_cidr_blocks = local.ingress_site_v4_cidr_blocks
    port           = 443
  }

  ingress {
    protocol       = "TCP"
    description    = "zabbix"
    v4_cidr_blocks = local.ingress_site_v4_cidr_blocks
    port           = 8080
  }

  ingress {
    protocol       = "TCP"
    description    = "kibana"
    v4_cidr_blocks = local.ingress_site_v4_cidr_blocks
    port           = 5601
  }

  ingress {
    protocol          = "TCP"
    description       = "healthchecks"
    predefined_target = "loadbalancer_healthchecks"
    port              = 30080
  }
  depends_on     = [yandex_vpc_network.network-1]
}


/*Создание группы безопасности для Web-серверов*/

resource "yandex_vpc_security_group" "alb-vm-sg" {
  name       = "alb-vm-sg"
  network_id = yandex_vpc_network.network-1.id

  ingress {
    protocol          = "TCP"
    description       = "balancer"
    security_group_id = yandex_vpc_security_group.alb-sg.id
    port              = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "ssh"
    security_group_id = yandex_vpc_security_group.sg-bastion-host.id
    port           = 22
  }

  ingress {
    protocol       = "TCP"
    description    = "zabbix"
    v4_cidr_blocks = ["172.16.0.0/12"]
    port           = 10050
  }

  egress {
    protocol       = "ANY"
    description    = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 1
    to_port        = 65535
  }
  depends_on     = [
    yandex_vpc_network.network-1,
    #yandex_vpc_security_group.alb-sg
    ]
}

/*Создание и настройка группы безопасности для zabbix*/

resource "yandex_vpc_security_group" "sg-zabbix" {
  name        = "sg-zabbix"
  description = "This rule for zabbix"
  network_id  = yandex_vpc_network.network-1.id


  ingress {
    protocol       = "TCP"
    description    = "ssh"
    security_group_id = yandex_vpc_security_group.sg-bastion-host.id
    port      = 22
  }

  ingress {
    protocol          = "TCP"
    description       = "balancer"
    security_group_id = yandex_vpc_security_group.alb-sg.id
    port              = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "zabbix"
    v4_cidr_blocks = ["172.16.0.0/12"]
    port           = 10050
  }

  egress {
    protocol       = "ANY"
    description    = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 1
    to_port        = 65535
  }
  depends_on     = [yandex_vpc_network.network-1]
}

/*Создание и настройка группы безопасности для Elasticsearch*/

resource "yandex_vpc_security_group" "sg-elasticsearch" {
  name        = "sg-elasticsearch"
  description = "This rule for elasticsearch"
  network_id  = yandex_vpc_network.network-1.id

  ingress {
    protocol       = "TCP"
    description    = "ssh"
    security_group_id = yandex_vpc_security_group.sg-bastion-host.id
    port      = 22
  }

  ingress {
    protocol       = "TCP"
    description    = "elasticsearch"
    v4_cidr_blocks = ["172.16.0.0/12"]
    port      = 9200
  }

  ingress {
    protocol       = "TCP"
    description    = "zabbix"
    v4_cidr_blocks = ["172.16.0.0/12"]
    port           = 10050
  }

  egress {
    protocol       = "ANY"
    description    = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 1
    to_port        = 65535
  }
  depends_on     = [yandex_vpc_network.network-1]
}

/*Создание и настройка группы безопасности для Kibana*/

resource "yandex_vpc_security_group" "sg-kibana" {
  name        = "sg-kibana"
  description = "This rule for kibana"
  network_id  = yandex_vpc_network.network-1.id

  ingress {
    protocol       = "TCP"
    description    = "ssh"
    security_group_id = yandex_vpc_security_group.sg-bastion-host.id
    port      = 22
  }

  ingress {
    protocol          = "TCP"
    description       = "balancer"
    security_group_id = yandex_vpc_security_group.alb-sg.id
    port              = 5601
  }

  ingress {
    protocol       = "TCP"
    description    = "zabbix"
    v4_cidr_blocks = ["172.16.0.0/12"]
    port           = 10050
  }
  
  egress {
    protocol       = "ANY"
    description    = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 1
    to_port        = 65535
  }
  depends_on     = [yandex_vpc_network.network-1]
}


/* Создание образов загрузочных дисков */

resource "yandex_compute_image" "web_server" {
  name          = "web-server"
  source_family = "lemp"
}


resource "yandex_compute_image" "debian-11" {
  name          = "debian-11"
  source_family = "debian-11"
}


/*Создание и настройка бастионного хоста*/

resource "yandex_compute_instance" "vm-bastion-host" {
  name                      = "vm-bastion-host"
  platform_id               = "standard-v2"
  zone = "ru-central1-b"
  allow_stopping_for_update = true
  hostname                  = "bastion"

  resources {
    core_fraction = 5
    cores         = 2
    memory        = 1
  }

  scheduling_policy {
    preemptible = false
  }

  boot_disk {
    initialize_params {
      name = "bastion"
      image_id = yandex_compute_image.debian-11.id
      size     = 3
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet-2.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.sg-bastion-host.id]
  }

  metadata = {
    user-data = file("./meta.yml")
  }
  
  depends_on = [
    yandex_compute_image.debian-11,
    yandex_vpc_subnet.subnet-2,
    yandex_vpc_security_group.sg-bastion-host
    ]

}


/*******************Создание Web-сервера № 1 *********************/

resource "yandex_compute_instance" "web-server-1" {
  name                      = "web-server-1"
  platform_id               = "standard-v2"
  zone = "ru-central1-a"
  allow_stopping_for_update = true
  hostname                  = "web-server-1"

  resources {
    core_fraction = 5
    cores         = 2
    memory        = 1
  }

  scheduling_policy {
    preemptible = false
  }

  boot_disk {
    initialize_params {
      name = "web-server-1"
      image_id = yandex_compute_image.web_server.id
      size     = 3
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet-1.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.alb-vm-sg.id]
  }

  metadata = {
    user-data = file("./meta.yml")
  }
  
  depends_on = [
    yandex_vpc_security_group.alb-vm-sg,
    yandex_compute_image.web_server,
    yandex_vpc_subnet.subnet-1
    ]
}


/*******************Создание Web-сервера № 2 *********************/

resource "yandex_compute_instance" "web-server-2" {
  name                      = "web-server-2"
  platform_id               = "standard-v2"
  zone = "ru-central1-b"
  allow_stopping_for_update = true
  hostname                  = "web-server-2"

  resources {
    core_fraction = 5
    cores         = 2
    memory        = 1
  }

  scheduling_policy {
    preemptible = false
  }

  boot_disk {
    initialize_params {
      name = "web-server-2"
      image_id = yandex_compute_image.web_server.id
      size     = 3
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet-2.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.alb-vm-sg.id]
  }

  metadata = {
    user-data = file("./meta.yml")
  }
  
  depends_on = [
    yandex_vpc_security_group.alb-vm-sg,
    yandex_compute_image.web_server,
    yandex_vpc_subnet.subnet-2
    ]
}


/*Создание и настройка zabbix*/

resource "yandex_compute_instance" "vm-zabbix" {
  name                      = "vm-zabbix"
  platform_id               = "standard-v2"
  zone                      = "ru-central1-b"
  allow_stopping_for_update = true
  hostname                  = "zabbix"

  resources {
    core_fraction = 20
    cores         = 2
    memory        = 2
  }

  scheduling_policy {
    preemptible = false
  }

  boot_disk {
    initialize_params {
      name = "zabbix"
      image_id = yandex_compute_image.debian-11.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet-2.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.sg-zabbix.id]
  }

  metadata = {
    user-data = file("./meta.yml")
  }

  depends_on = [
    yandex_vpc_security_group.sg-zabbix,
    yandex_compute_image.debian-11,
    yandex_vpc_subnet.subnet-2
    ]

}

/*Создание и настройка Elasticsearch*/

resource "yandex_compute_instance" "vm-elasticsearch" {
  name                      = "vm-elasticsearch"
  platform_id               = "standard-v2"
  zone                      = "ru-central1-b"
  allow_stopping_for_update = true
  hostname                  = "elasticsearch"

  resources {
    core_fraction = 5
    cores         = 2
    memory        = 2
  }

  scheduling_policy {
    preemptible = false
  }

  boot_disk {
    initialize_params {
      name = "elasticsearch"
      image_id = yandex_compute_image.debian-11.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet-2.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.sg-elasticsearch.id]
  }

  metadata = {
    user-data = file("./meta.yml")
  }

  depends_on = [
    yandex_vpc_security_group.sg-elasticsearch,
    yandex_compute_image.debian-11,
    yandex_vpc_subnet.subnet-2
    ]

}


/*Создание и настройка kibana*/

resource "yandex_compute_instance" "vm-kibana" {
  name                      = "vm-kibana"
  platform_id               = "standard-v2"
  zone                      = "ru-central1-b"
  allow_stopping_for_update = true
  hostname                  = "kibana"

  resources {
    core_fraction = 5
    cores         = 2
    memory        = 2
  }

  scheduling_policy {
    preemptible = false
  }

  boot_disk {
    
    initialize_params {
      name = "kibana"
      image_id = yandex_compute_image.debian-11.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet-2.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.sg-kibana.id]
  }

  metadata = {
    user-data = file("./meta.yml")
  }

  depends_on = [
    yandex_vpc_security_group.sg-kibana,
    yandex_compute_image.debian-11,
    yandex_vpc_subnet.subnet-2
    ]

}


/* Создание группы таргетов для web-серверов */

resource "yandex_alb_target_group" "alb-tg" {
  name           = "web-servers-tg"

  target {
    subnet_id    = yandex_vpc_subnet.subnet-1.id
      ip_address   = yandex_compute_instance.web-server-1.network_interface[0].ip_address
  }

    target {
    subnet_id    = yandex_vpc_subnet.subnet-2.id
      ip_address   = yandex_compute_instance.web-server-2.network_interface[0].ip_address
  }

  depends_on = [
    yandex_compute_instance.web-server-1,
    yandex_compute_instance.web-server-2
    ]

}

/* Создание группы таргетов для zabbix */

resource "yandex_alb_target_group" "zabbix-tg" {
  name           = "zabbix-tg"

  target {
    subnet_id    = yandex_vpc_subnet.subnet-2.id
      ip_address   = yandex_compute_instance.vm-zabbix.network_interface[0].ip_address
  }

  depends_on = [yandex_compute_instance.vm-zabbix]

}

/* Создание группы таргетов для kibana */

resource "yandex_alb_target_group" "kibana-tg" {
  name           = "kibana-tg"

  target {
    subnet_id    = yandex_vpc_subnet.subnet-2.id
    ip_address   = yandex_compute_instance.vm-kibana.network_interface[0].ip_address
  }
  
  depends_on = [yandex_compute_instance.vm-kibana]
}



/* Создание группы бекендеров для web-серверов */

resource "yandex_alb_backend_group" "alb-bg" {
  name = "alb-bg"

  http_backend {
    name             = "backend-1"
    port             = 80
    target_group_ids = [ yandex_alb_target_group.alb-tg.id ]
    healthcheck {
      timeout          = "10s"
      interval         = "2s"
      healthcheck_port = 80
      http_healthcheck {
        path = "/"
      }
    }
  }
  depends_on = [
  yandex_compute_instance.web-server-1,
  yandex_compute_instance.web-server-2
  ]
}

/* Создание группы бекендеров для zabbix */

resource "yandex_alb_backend_group" "zabbix-bg" {
  name = "zabbix-bg"

  http_backend {
    name             = "backend-1"
    port             = 80
    target_group_ids = [ yandex_alb_target_group.zabbix-tg.id ]
 }

 depends_on = [yandex_alb_target_group.zabbix-tg]

}

/* Создание группы бекендеров для kibana */

resource "yandex_alb_backend_group" "kibana-bg" {
  name = "kibana-bg"

  http_backend {
    name             = "backend-1"
    port             = 5601
    target_group_ids = [yandex_alb_target_group.kibana-tg.id]
 }

 depends_on = [yandex_alb_target_group.kibana-tg]

}


/* Создание HTTP роутера для web-серверов */

resource "yandex_alb_http_router" "alb-router" {
  name = "alb-router"
  depends_on = [yandex_alb_backend_group.alb-bg]
}

/* Создание HTTP роутера для zabbix */

resource "yandex_alb_http_router" "zabbix-router" {
  name = "zabbix-router"
  depends_on = [yandex_alb_backend_group.zabbix-bg]
}

/* Создание HTTP роутера для kibana */

resource "yandex_alb_http_router" "kibana-router" {
  name = "kibana-router"
  depends_on = [yandex_alb_backend_group.kibana-bg]
}

/* Создание виртуального хоста для web-серверов */

resource "yandex_alb_virtual_host" "alb-host" {
  name           = "alb-host"
  http_router_id = yandex_alb_http_router.alb-router.id
  authority      = [var.domain, "www.${var.domain}"]
  route {
    name = "route-1"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.alb-bg.id
      }
    }
  }
  depends_on = [yandex_alb_http_router.alb-router]
}

/* Создание виртуального хоста для zabbix */

resource "yandex_alb_virtual_host" "zabbix-host" {
  name           = "zabbix-host"
  http_router_id = yandex_alb_http_router.zabbix-router.id
  authority      = [var.domain, "www.${var.domain}"]
  route {
    name = "route-1"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.zabbix-bg.id
      }
    }
  }
  depends_on = [
      yandex_alb_http_router.zabbix-router,
      yandex_alb_backend_group.zabbix-bg
  ]
}

/* Создание виртуального хоста для kibana */

resource "yandex_alb_virtual_host" "kibana-host" {
  name           = "kibana-host"
  http_router_id = yandex_alb_http_router.kibana-router.id
  authority      = [var.domain, "www.${var.domain}"]
  route {
    name = "route-1"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.kibana-bg.id
      }
    }
  }
  depends_on = [
      yandex_alb_http_router.kibana-router,
      yandex_alb_backend_group.kibana-bg
  ]
}


/* Добавление зоны */

resource "yandex_dns_zone" "alb-zone" {
  name        = "alb-zone"
  description = "Public zone"
  zone        = "${var.domain}."
  public      = true
}

/* Выпуск сертификата */

resource "yandex_cm_certificate" "le-certificate" {
  name    = "le-certificate"
  domains = [var.domain]
  deletion_protection = true
  managed {
  challenge_type = "DNS_CNAME"
  }
}


/* Валидация сертфиката */

resource "yandex_dns_recordset" "validation-record" {
  zone_id = yandex_dns_zone.alb-zone.id
  name    = yandex_cm_certificate.le-certificate.challenges[0].dns_name
  type    = yandex_cm_certificate.le-certificate.challenges[0].dns_type
  data    = [yandex_cm_certificate.le-certificate.challenges[0].dns_value]
  ttl     = 300
  depends_on = [yandex_cm_certificate.le-certificate,
                yandex_dns_zone.alb-zone
               ]
}


data "yandex_cm_certificate" "cert" {
  depends_on      = [yandex_dns_recordset.validation-record]
  certificate_id  = yandex_cm_certificate.le-certificate.id
  wait_validation = true
}

/* Создание L7-балансировщика */

resource "yandex_alb_load_balancer" "alb-1" {
  name               = "alb-1"
  network_id         = yandex_vpc_network.network-1.id
  security_group_ids = [yandex_vpc_security_group.alb-sg.id]

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.subnet-1.id
    }

    location {
      zone_id   = "ru-central1-b"
      subnet_id = yandex_vpc_subnet.subnet-2.id
    }

  }

  listener {

    name = "alb-listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [443]
    }
    
    tls {
      default_handler {
        certificate_ids = [data.yandex_cm_certificate.cert.id]
        http_handler {
          http_router_id = yandex_alb_http_router.alb-router.id
          }
        }
    }
    
    
  }


  listener {
    name = "redirect"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [80]
    }

    http {
      redirects {
        http_to_https = true
      }
    }

  }

  listener {
    name = "zabbix-listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [8080]
    }
    
    tls {
      default_handler {
        certificate_ids = [data.yandex_cm_certificate.cert.id]
        http_handler {
          http_router_id = yandex_alb_http_router.zabbix-router.id
          }
        }
    }
    
  }

  listener {
    name = "kibana-listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [5601]
    }
    
    tls {
      default_handler {
        certificate_ids = [data.yandex_cm_certificate.cert.id]
        http_handler {
          http_router_id = yandex_alb_http_router.kibana-router.id
          }
        }
    }
    
  }

  depends_on = [yandex_alb_virtual_host.alb-host,
               yandex_vpc_security_group.alb-sg,
               yandex_alb_http_router.alb-router,
               yandex_alb_http_router.zabbix-router,
               yandex_alb_http_router.kibana-router,
               data.yandex_cm_certificate.cert
               ]
}

/* Добавление ресурсных записей */

resource "yandex_dns_recordset" "rs-1" {
  zone_id = yandex_dns_zone.alb-zone.id
  name    = "${var.domain}."
  ttl     = 600
  type    = "A"
  data    = [yandex_alb_load_balancer.alb-1.listener[0].endpoint[0].address[0].external_ipv4_address[0].address]
  depends_on = [
                yandex_dns_zone.alb-zone,
                yandex_alb_load_balancer.alb-1
                ]
}

resource "yandex_dns_recordset" "rs-2" {
  zone_id = yandex_dns_zone.alb-zone.id
  name    = "www"
  ttl     = 600
  type    = "CNAME"
  data    = [var.domain]
    depends_on = [
                yandex_dns_zone.alb-zone,
                yandex_alb_load_balancer.alb-1
                ]
}

/* Настройка автоматического создания снимков дисков по расписанию */
resource "yandex_compute_snapshot_schedule" "snapshot-schedule" {
  name = "snapshot-schedule"

  schedule_policy {
    expression = "10 23 ? * *"
  }

  snapshot_count = 7

  snapshot_spec {
    description = "disk snapshots"
  }

  disk_ids = [
    yandex_compute_instance.vm-bastion-host.boot_disk[0].disk_id,
    yandex_compute_instance.vm-zabbix.boot_disk[0].disk_id,
    yandex_compute_instance.vm-elasticsearch.boot_disk[0].disk_id,
    yandex_compute_instance.vm-kibana.boot_disk[0].disk_id,
    yandex_compute_instance.web-server-1.boot_disk[0].disk_id,
    yandex_compute_instance.web-server-2.boot_disk[0].disk_id
    ]

   depends_on = [
    yandex_compute_instance.vm-bastion-host,
    yandex_compute_instance.vm-zabbix,
    yandex_compute_instance.vm-elasticsearch,
    yandex_compute_instance.vm-kibana,
    yandex_compute_instance.web-server-1,
    yandex_compute_instance.web-server-2
   ]

}

