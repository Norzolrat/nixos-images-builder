# ════════════════════════════════════════
#  GPU TEST  ——  AMD ROCm / PyTorch  🎮
# ════════════════════════════════════════
#
# Prérequis sur le node GPU :
#   kubectl --kubeconfig ../export/kubeconfig \
#     label node <nom-du-node-gpu> gpu=amd --overwrite
#
# Ex. si le node s'appelle "kube-worker-3" :
#   kubectl label node kube-worker-3 gpu=amd --overwrite
#
# Vérifier que le AMD GPU device plugin est actif :
#   kubectl get nodes -o custom-columns=\
#     "NODE:.metadata.name,GPU:.status.capacity.amd\.com/gpu"
# ════════════════════════════════════════

# ── ConfigMap : script Python de test GPU ──────────────────────

resource "kubernetes_config_map_v1" "gpu_test_script" {
  metadata {
    name      = "gpu-test-script"
    namespace = kubernetes_namespace_v1.hello_world.metadata[0].name
    labels = {
      app        = "gpu-test"
      managed-by = "terraform"
    }
  }

  data = {
    "gpu_test.py" = <<-PYEOF
      #!/usr/bin/env python3
      """
      Test GPU AMD — ROCm (rocminfo / rocm-smi / HIP Python)
      ============================================================
      Image : rocm/rocm-terminal  (~2 GB, légère)
      Vérifie que le GPU AMD est bien accessible depuis le pod
      Kubernetes via les devices /dev/kfd et /dev/dri.
      ============================================================
      """

      import sys
      import subprocess
      import os

      SEP = "=" * 62
      gpu_detected = False

      print(SEP)
      print("  🎮  TEST GPU AMD — ROCm")
      print(SEP)
      print(f"\n  Node     : {os.environ.get('NODE_NAME', 'inconnu')}")
      print(f"  Pod      : {os.environ.get('POD_NAME',  'inconnu')}")

      # ── 1. /dev/kfd et /dev/dri présents ? ─────────────────────
      print("\n[1/4] Devices ROCm sur le host :")
      for dev in ["/dev/kfd", "/dev/dri"]:
          exists = os.path.exists(dev)
          kind   = "dir" if os.path.isdir(dev) else "char" if os.path.exists(dev) else "ABSENT"
          status = "✅" if exists else "❌"
          print(f"  {status}  {dev}  ({kind})")
          if dev == "/dev/kfd" and exists:
              gpu_detected = True

      if os.path.isdir("/dev/dri"):
          renders = [f for f in os.listdir("/dev/dri") if f.startswith("render")]
          print(f"     renderD nodes : {renders if renders else 'aucun'}")

      # ── 2. rocminfo ─────────────────────────────────────────────
      print("\n[2/4] rocminfo — agents GPU détectés :")
      try:
          result = subprocess.run(
              ["rocminfo"], capture_output=True, text=True, timeout=60
          )
          keywords = ["Agent", "Name:", "Marketing", "Compute Unit",
                      "Max Clock", "gfx", "Uuid"]
          found_gpu = False
          for line in result.stdout.splitlines():
              if any(kw in line for kw in keywords):
                  print(f"  {line.strip()}")
                  if "gfx" in line or "Marketing" in line:
                      found_gpu = True
          if found_gpu:
              gpu_detected = True
              print("  ✅  GPU AMD détecté par rocminfo")
          else:
              print("  ⚠   Aucun agent GPU dans rocminfo")
          if result.returncode != 0:
              print(f"  stderr: {result.stderr[:400]}")
      except FileNotFoundError:
          print("  rocminfo absent de l'image")
      except subprocess.TimeoutExpired:
          print("  rocminfo timeout (>60 s)")
      except Exception as exc:
          print(f"  Erreur: {exc}")

      # ── 3. rocm-smi ─────────────────────────────────────────────
      print("\n[3/4] rocm-smi — état de la carte :")
      try:
          result = subprocess.run(
              ["rocm-smi", "--showproductname", "--showmeminfo", "vram",
               "--showuse", "--showtemp"],
              capture_output=True, text=True, timeout=30
          )
          output = result.stdout.strip()
          if output:
              print(output[:1500])
              gpu_detected = True
          else:
              print("  (aucune sortie)")
          if result.returncode != 0:
              print(f"  stderr: {result.stderr[:300]}")
      except FileNotFoundError:
          print("  rocm-smi absent de l'image")
      except Exception as exc:
          print(f"  Erreur: {exc}")

      # ── 4. PyTorch / HIP (optionnel) ────────────────────────────
      print("\n[4/4] PyTorch ROCm (optionnel — non inclus dans rocm-terminal) :")
      try:
          import torch
          print(f"  PyTorch version  : {torch.__version__}")
          avail = torch.cuda.is_available()
          count = torch.cuda.device_count()
          print(f"  CUDA/ROCm dispo  : {avail}")
          print(f"  Nb GPU détectés  : {count}")
          if avail and count > 0:
              p = torch.cuda.get_device_properties(0)
              print(f"  GPU [0]  : {p.name}  —  {p.total_memory // 1024**2} MiB")
              # Calcul rapide
              import time
              N = 1024
              a = torch.rand(N, N, device="cuda")
              b = torch.rand(N, N, device="cuda")
              torch.cuda.synchronize()
              t0 = time.perf_counter()
              c = torch.matmul(a, b)
              torch.cuda.synchronize()
              ms = (time.perf_counter() - t0) * 1000
              print(f"  matmul {N}×{N} : {ms:.1f} ms  —  sum={c.sum().item():.2f}")
              print("  ✅  Calcul PyTorch GPU réussi !")
              gpu_detected = True
      except ImportError:
          print("  ℹ   PyTorch absent (normal avec rocm-terminal)")
          print("      Pour PyTorch : changer l'image pour rocm/pytorch")
          print("      (nécessite ~15 GB d'espace disque sur le node)")
      except Exception as exc:
          print(f"  Erreur PyTorch: {exc}")

      # ── Verdict ─────────────────────────────────────────────────
      print("\n" + SEP)
      if gpu_detected:
          print("  ✅  RÉSULTAT : GPU AMD accessible depuis le pod Kubernetes !")
      else:
          print("  ❌  RÉSULTAT : GPU AMD NON détecté")
          print("      → Vérifier label node : kubectl label node nixos-kube-worker-3 gpu=amd")
          print("      → Vérifier device plugin AMD : kubectl get ds -A | grep amd")
          sys.exit(1)
      print(SEP)
    PYEOF
  }
}

# ── Job Kubernetes — test GPU AMD ──────────────────────────────

resource "kubernetes_job_v1" "gpu_test" {
  metadata {
    name      = "gpu-test-amd"
    namespace = kubernetes_namespace_v1.hello_world.metadata[0].name
    labels = {
      app        = "gpu-test"
      managed-by = "terraform"
    }
  }

  spec {
    # 2 tentatives max avant d'être marqué Failed
    backoff_limit = 2

    # Conserver le Job 10 min après complétion pour pouvoir lire les logs
    ttl_seconds_after_finished = 600

    template {
      metadata {
        labels = {
          app = "gpu-test"
        }
      }

      spec {
        # ── Épinglage sur le node GPU AMD ────────────────────────
        node_selector = {
          (var.gpu_node_label_key) = var.gpu_node_label_value
        }

        # Ne pas redémarrer automatiquement le pod
        restart_policy = "Never"

        container {
          name  = "gpu-test"
          image = var.pytorch_rocm_image

          command = ["python3", "/scripts/gpu_test.py"]

          # Variables d'env pour le reporting dans les logs
          env {
            name = "NODE_NAME"
            value_from {
              field_ref { field_path = "spec.nodeName" }
            }
          }
          env {
            name = "POD_NAME"
            value_from {
              field_ref { field_path = "metadata.name" }
            }
          }

          # ── Ressource AMD GPU (nécessite le device plugin) ──────
          resources {
            limits = {
              "amd.com/gpu" = "1"
              cpu            = "2"
              memory         = "2Gi"
            }
            requests = {
              "amd.com/gpu" = "1"
              cpu            = "500m"
              memory         = "1Gi"
            }
          }

          # ── Script Python depuis le ConfigMap ────────────────────
          volume_mount {
            name       = "scripts"
            mount_path = "/scripts"
            read_only  = true
          }

          # ── Accès direct aux devices ROCm ────────────────────────
          # (le device plugin les monte aussi automatiquement ;
          #  ces entrées servent de garde-fou si le plugin est absent)
          volume_mount {
            name       = "dev-kfd"
            mount_path = "/dev/kfd"
          }

          volume_mount {
            name       = "dev-dri"
            mount_path = "/dev/dri"
          }

          security_context {
            # Requis pour accéder aux devices PCIe passthrough
            privileged = true
          }
        }

        # ── Volumes ──────────────────────────────────────────────

        volume {
          name = "scripts"
          config_map {
            name         = kubernetes_config_map_v1.gpu_test_script.metadata[0].name
            default_mode = "0555"
          }
        }

        volume {
          name = "dev-kfd"
          host_path {
            path = "/dev/kfd"
            type = "CharDevice"
          }
        }

        volume {
          name = "dev-dri"
          host_path {
            path = "/dev/dri"
            type = "Directory"
          }
        }
      }
    }
  }

  # terraform apply ne bloque pas en attendant la complétion du Job
  wait_for_completion = false

  timeouts {
    create = "5m"
    update = "5m"
  }
}
