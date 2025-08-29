# GitHub Actions Self-Hosted Runner con k0s en Proxmox

Este proyecto despliega un clúster k0s en Proxmox utilizando Terraform. El objetivo es contar con un runner autohospedado y efímero para GitHub Actions, gestionado mediante el Actions Runner Controller (ARC). Además, se integra cert-manager y MetalLB para gestionar certificados y balanceo de carga, respectivamente.

## Arquitectura

- **Proxmox + Terraform:** Se utiliza Terraform para crear y configurar una VM (o VMs) en Proxmox, clonando una plantilla Debian.
- **k0s:** Instalación y configuración de un clúster Kubernetes ligero (k0s) sobre la VM.
- **Cert-Manager:** Para la gestión de certificados (requerido por ARC).
- **Actions Runner Controller (ARC):** Administra la creación y eliminación dinámica de runners efímeros en el clúster.
- **HorizontalRunnerAutoscaler:** Permite escalar los runners según la demanda de jobs en GitHub Actions.

## Requisitos

- Proxmox con un template Debian.
- Terraform.
- Conexión SSH configurada para acceder a la VM.
- Acceso a GitHub con permiso para crear un GitHub App y generar el token/clave privada (.pem).

## Cómo desplegar

1. **Configura las variables de Terraform:**  
   Define en los archivos de variables:
   - `vm_user`
   - `vm_private_key_path`
   - `ips_nodes`, `gw` y demás variables propias del entorno.
   - Nombre del repositorio, etc.

2. **Aplica la infraestructura con Terraform:**  
   Ejecuta:
   ```bash
   terraform init
   terraform apply
   ```
   Esto creará la VM en Proxmox, instalará k0s y aplicará los manifiestos necesarios (cert-manager, MetalLB, ARC, etc.).

3. **Obtén el kubeconfig:**  
   Una vez que el clúster esté listo, se fusiona el kubeconfig obtenido de k0s en `~/.kube/config` para facilitar futuras consultas.

4. **Verifica el despliegue:**  
   Listar los pods en el namespace `actions-runner-system`:
   ```bash
   kubectl get pods -n actions-runner-system
   ```
   Deberías ver un pod similar a:
   ```
   NAME                                             READY   STATUS    RESTARTS   AGE
   arc-actions-runner-controller-xxxxxxxxxxxxxxxxx   2/2     Running   0          23h
   ```

## Uso en GitHub Actions

El proyecto incluye un archivo de workflow de ejemplo: `.github/workflows/main.yml`.  
Este workflow está configurado para ejecutarse en runners efímeros mediante:
```yaml
runs-on: [self-hosted, k0s, ephemeral]
```
Cuando se active un job en GitHub (por push, pull-request o manualmente), ARC lanzará un pod runner efímero en el clúster para ejecutar el job.

## Troubleshooting

- **Error de webhook**:  
  Si al aplicar el manifiesto del RunnerDeployment aparece un error relacionado con el webhook, asegúrate de que ARC y cert-manager estén completamente instalados y sus pods estén en estado `Running`. Puede ser necesario agregar esperas adicionales en la secuencia de provisión.

- **Advertencias SSH:**  
  Si al obtener el kubeconfig aparece una advertencia sobre host keys cambiadas, elimina la entrada problemática en `/root/.ssh/known<vscode_annotation details='%5B%7B%22title%22%3A%22hardcoded