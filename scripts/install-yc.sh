#!/bin/bash
sudo apt update;
sudo apt upgrade;
sudo apt install curl -y;
curl -sSL https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash;
source ~/.bashrc;
yc init;
