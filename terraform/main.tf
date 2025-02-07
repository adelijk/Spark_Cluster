# main.tf
terraform {
  required_providers {
    lxd = {
      source  = "terraform-lxd/lxd"
      version = "2.4.0"
    }
  }
}

provider "lxd" {}

resource "lxd_instance" "spark_master" {
  name      = var.master_name
  image     = var.image
  ephemeral = false
  profiles  = ["default"]

  provisioner "local-exec" {
    command = <<-EOT
      lxc exec ${var.master_name} -- bash -c '
        apt-get update && apt-get install -y openssh-server sshpass python3 && 
        sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config && 
        sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config && 
        useradd -m -s /bin/bash ${var.user} && 
        echo "${var.user}:${var.user_password}" | chpasswd && 
        usermod -aG sudo ${var.user} && 
        systemctl restart ssh
      '
    EOT
  }
}

resource "lxd_instance" "spark_worker" {
  count     = var.worker_count
  name      = "spark-worker-${count.index + 1}"
  image     = var.image
  ephemeral = false
  profiles  = ["default"]

  provisioner "local-exec" {
    command = <<-EOT
      lxc exec spark-worker-${count.index + 1} -- bash -c '
        apt-get update && apt-get install -y openssh-server sshpass python3 && 
        sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config && 
        sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config && 
        useradd -m -s /bin/bash ${var.user} && 
        echo "${var.user}:${var.user_password}" | chpasswd && 
        usermod -aG sudo ${var.user} && 
        systemctl restart ssh
      '
    EOT
  }
}

data "external" "master_ip" {
  depends_on = [lxd_instance.spark_master]
  program    = ["sh", "-c", "echo '{\"ip\": \"'$(lxc list ${var.master_name} -c 4 --format csv | cut -d' ' -f1)'\"}'"]
}

data "external" "worker_ips" {
  count      = var.worker_count
  depends_on = [lxd_instance.spark_worker]
  program    = ["sh", "-c", "echo '{\"ip\": \"'$(lxc list spark-worker-${count.index + 1} -c 4 --format csv | cut -d' ' -f1)'\"}'"]
}

resource "local_file" "ansible_inventory" {
  depends_on = [data.external.master_ip, data.external.worker_ips]
  content = templatefile("${path.module}/templates/inventory.tpl", {
    master_ip  = data.external.master_ip.result.ip,
    worker_ips = [for ip in data.external.worker_ips : ip.result.ip]
  })
  filename = "${path.module}/../ansible/inventory.yml"
}

output "master_ip" {
  value = data.external.master_ip.result.ip
}

output "worker_ips" {
  value = [for ip in data.external.worker_ips : ip.result.ip]
}
