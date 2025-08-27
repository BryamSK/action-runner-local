###Cluster K0s on Proxmox
# This Terraform configuration deploys a k0s cluster on Proxmox using a Debian template
resource "proxmox_vm_qemu" "k0s_single" {
  count           = 1
  name            = "runners-${var.gitrepo}-${count.index + 1}"
  target_nodes    = var.nodes
  clone           = "k0s"
  full_clone      = true
  bootdisk        = "scsi0"
  scsihw          = "virtio-scsi-pci"
  ssh_user        = var.vm_user
  ssh_private_key = file(var.vm_private_key_path)
  memory          = 4096
  agent           = 1
  os_type         = "cloud-init"
  ipconfig0       = "gw=${var.gw},ip=${element(var.ips_nodes, count.index)}/24"

  cpu {
    cores = 2
  }
  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = var.storage_pool
    size    = "10G"
  }
  disk {
    slot    = "scsi2"
    type    = "cloudinit"
    storage = var.storage_pool
  }
  network {
    id        = 0
    bridge    = "vmbr0"
    firewall  = false
    link_down = false
    model     = "virtio"
  }

  provisioner "file" {
    source      = "./config/metallb-config.yaml"
    destination = "/tmp/metallb-config.yaml"
    connection {
      type        = "ssh"
      user        = var.vm_user
      private_key = file(var.vm_private_key_path)
      host        = self.ssh_host
    }
  }

  provisioner "file" {
    source      = "./config/private-key.pem"
    destination = "/tmp/private-key.pem"
    connection {
      type        = "ssh"
      user        = var.vm_user
      private_key = file(var.vm_private_key_path)
      host        = self.ssh_host
    }
  }

  provisioner "file" {
    source      = "./config/runner-autoscaler.yaml"
    destination = "/tmp/runner-autoscaler.yaml"
    connection {
      type        = "ssh"
      user        = var.vm_user
      private_key = file(var.vm_private_key_path)
      host        = self.ssh_host
    }
  }

  provisioner "file" {
    source      = "./config/runner-deployment.yaml"
    destination = "/tmp/runner-deployment.yaml"
    connection {
      type        = "ssh"
      user        = var.vm_user
      private_key = file(var.vm_private_key_path)
      host        = self.ssh_host
    }
  }

  provisioner "remote-exec" {
    inline = [
      "k0s install controller --single",
      "systemctl daemon-reload",
      "systemctl enable k0scontroller",
      "systemctl start k0scontroller",
      "sleep 20",
      "k0s kubeconfig admin > kubeconfig",
      "until k0s kubectl get nodes --insecure-skip-tls-verify=true; do echo 'Esperando k0s...'; sleep 5; done",
      "mv /tmp/metallb-config.yaml .",
      "mv /tmp/private-key.pem .",
      "mv /tmp/runner-autoscaler.yaml .",
      "mv /tmp/runner-deployment.yaml .",
      "k0s kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml",
      "k0s kubectl wait -n metallb-system --for=condition=Available deployment/controller --timeout=180s",
      "k0s kubectl wait -n metallb-system --for=condition=Available deployment/speaker --timeout=180s",
      "sleep 20",
      "k0s kubectl apply -f metallb-config.yaml",
      "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash",
      "helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller",
      "helm repo update",
      "k0s kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml",
      "k0s kubectl wait --for=condition=Available --timeout=180s -n cert-manager deployment/cert-manager",
      "sleep 20",
      "helm upgrade --kubeconfig ./kubeconfig --install arc actions-runner-controller/actions-runner-controller --namespace actions-runner-system --create-namespace",
      "sleep 20",      
      "k0s kubectl create secret generic controller-manager -n actions-runner-system --from-literal=github_app_id=1848327 --from-literal=github_app_installation_id=82923522 --from-file=github_app_private_key=private-key.pem",
      "sleep 20",
      "k0s kubectl apply -f runner-autoscaler.yaml",
      "sleep 20",
      "k0s kubectl apply -f runner-deployment.yaml",
    ]

    connection {
      type        = "ssh"
      user        = var.vm_user
      private_key = file(var.vm_private_key_path)
      host        = self.ssh_host
    }
  }
}

output "vm_ip_single" {
  value = [for vm in proxmox_vm_qemu.k0s_single : vm.ssh_host]
}


resource "null_resource" "wait_for_ssh" {
  provisioner "remote-exec" {
    inline = ["echo 'SSH is ready'"]
    connection {
      type        = "ssh"
      user        = var.vm_user
      private_key = file(var.vm_private_key_path)
      host        = proxmox_vm_qemu.k0s_single[0].ssh_host
    }
  }

  depends_on = [proxmox_vm_qemu.k0s_single]
}

resource "null_resource" "get_kubeconfig" {
  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ${var.vm_private_key_path} root@${proxmox_vm_qemu.k0s_single[0].ssh_host}:/root/kubeconfig ./kubeconfig-${proxmox_vm_qemu.k0s_single[0].name}"
  }

  depends_on = [null_resource.wait_for_ssh, proxmox_vm_qemu.k0s_single]
}

resource "null_resource" "merge_kubeconfigs" {
  provisioner "local-exec" {
    command = "export KUBECONFIG=$(find . -name 'kubeconfig-*' | paste -sd :) && kubectl config view --flatten > ~/.kube/config"
  }
  depends_on = [null_resource.get_kubeconfig]
}
