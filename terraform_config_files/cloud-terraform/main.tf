# Локальные переменные

locals {
  sa_name      = "ig-sa"
  network_name = "network1"
  subnet_name1 = "subnet-1"
  subnet_name2 = "subnet-2"
  subnet_name3 = "subnet-3"
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

# Создание сервисного аккаунта. Все операции в Instance Groups будут выполняются от имени этого сервисного аккаунта.

resource "yandex_iam_service_account" "ig-sa" {
  name        = local.sa_name
  description = "service account to manage instance groups"
}

# Создание роли для сервисного аккаунта. Чтобы иметь возможность создавать, обновлять и удалять ВМ в группе, сервисному аккаунту назначается роль editor.

resource "yandex_resourcemanager_folder_iam_member" "editor" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.ig-sa.id}"
}

/*Настройка сети*/


resource "yandex_vpc_network" "network-1" {
  name = local.network_name
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = local.subnet_name1
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["172.16.0.0/24"]
}

resource "yandex_vpc_subnet" "subnet-2" {
  name           = local.subnet_name2
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["172.16.1.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id

}

resource "yandex_vpc_subnet" "subnet-3" {
  name           = local.subnet_name3
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["172.16.2.0/24"]
  route_table_id = yandex_vpc_route_table.rt.id
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
}

/* Создание образов загрузочных дисков */

resource "yandex_compute_image" "web_server" {
  name          = "web-server"
  source_family = "lemp"
}

resource "yandex_compute_image" "bastion_host" {
  name          = "bastion-host"
  source_family = "debian-11"
}

/*Создание группы безопасности для бастионного хоста*/

resource "yandex_vpc_security_group" "sg-bastion-host" {
  name        = "sg-bastion-host"
  description = "This rule allows access to the bastion host from the internet"
  network_id  = yandex_vpc_network.network-1.id

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  egress {
    protocol       = "ANY"
    description    = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 1
    to_port        = 65535
  }

}


/*Создание и настройка бастионного хоста*/


resource "yandex_compute_instance" "vm-bastion-host" {
  name                      = "vm-bastion-host"
  platform_id               = "standard-v2"
  allow_stopping_for_update = true
  hostname                  = "bastion"

  resources {
    core_fraction = 5
    cores         = 2
    memory        = 1
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = yandex_compute_image.bastion_host.id
      size     = 3
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet-1.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.sg-bastion-host.id]
  }

  metadata = {
    user-data = file("./meta.yml")
  }

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
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "ext-https"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    protocol          = "TCP"
    description       = "healthchecks"
    predefined_target = "loadbalancer_healthchecks"
    port              = 30080
  }
}


/*Создание группы безопасности для группы виртуальных машин*/

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
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  egress {
    protocol       = "ANY"
    description    = "any"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 1
    to_port        = 65535
  }


}


/* Создание и настройка группы виртуальных машин */

resource "yandex_compute_instance_group" "alb-vm-group" {
  name                = "alb-vm-group"
  folder_id           = var.folder_id
  service_account_id  = yandex_iam_service_account.ig-sa.id
  deletion_protection = "false"

  instance_template {
    platform_id = "standard-v2"

    resources {
      core_fraction = 5
      memory        = 1
      cores         = 2
    }

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = yandex_compute_image.web_server.id
        type     = "network-hdd"
        size     = 3
      }
    }

    scheduling_policy {
      preemptible = true
    }
    hostname = "web-server-{instance.index}"
    network_interface {
      network_id         = yandex_vpc_network.network-1.id
      subnet_ids         = [yandex_vpc_subnet.subnet-2.id, yandex_vpc_subnet.subnet-3.id]
      nat                = false
      security_group_ids = [yandex_vpc_security_group.alb-vm-sg.id]
    }

    metadata = {
      user-data = file("./meta.yml")
    }
  }

  scale_policy {

    /*
    auto_scale {
      initial_size           = 2
      measurement_duration   = 60
      max_size               = 3
      min_zone_size          = 1
      cpu_utilization_target = 75
      warmup_duration        = 60
      stabilization_duration = 120
    }
    */

    fixed_scale {
      size = 2
    }

  }

  allocation_policy {
    zones = ["ru-central1-a", "ru-central1-b"]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }

  application_load_balancer {
    target_group_name        = "alb-tg"
    target_group_description = "load balancer target group"
  }

}

/* Создание группы бекендеров */
resource "yandex_alb_backend_group" "alb-bg" {
  name = "alb-bg"

  http_backend {
    name             = "backend-1"
    port             = 80
    target_group_ids = [yandex_compute_instance_group.alb-vm-group.application_load_balancer.0.target_group_id]
    healthcheck {
      timeout          = "10s"
      interval         = "2s"
      healthcheck_port = 80
      http_healthcheck {
        path = "/"
      }
    }
  }
}

/* Создание HTTP роутера */
resource "yandex_alb_http_router" "alb-router" {
  name = "alb-router"
}

/* Создание виртуального хоста */
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
}

/* Создание L7-балансировщика */

resource "yandex_alb_load_balancer" "alb-1" {
  name               = "alb-1"
  network_id         = yandex_vpc_network.network-1.id
  security_group_ids = [yandex_vpc_security_group.alb-sg.id]

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.subnet-3.id
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
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.alb-router.id
      }
    }
  }
}

/* Добавление зоны */

resource "yandex_dns_zone" "alb-zone" {
  name        = "alb-zone"
  description = "Public zone"
  zone        = "${var.domain}."
  public      = true
}

/* Добавление ресурсных записей */

resource "yandex_dns_recordset" "rs-1" {
  zone_id = yandex_dns_zone.alb-zone.id
  name    = "${var.domain}."
  ttl     = 600
  type    = "A"
  data    = [yandex_alb_load_balancer.alb-1.listener[0].endpoint[0].address[0].external_ipv4_address[0].address]
}


resource "yandex_dns_recordset" "rs-2" {
  zone_id = yandex_dns_zone.alb-zone.id
  name    = "www"
  ttl     = 600
  type    = "CNAME"
  data    = [var.domain]
}
