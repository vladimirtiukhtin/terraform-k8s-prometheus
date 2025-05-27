resource "kubernetes_deployment_v1" "kube_state_metrics" {

  metadata {
    name        = local.name.kube_state_metrics
    namespace   = var.namespace
    annotations = {}
    labels      = local.labels.kube_state_metrics
  }

  spec {
    replicas = var.replicas.kube-state-metrics // ToDo: check how HA works

    selector {
      match_labels = local.selector_labels.kube_state_metrics
    }

    template {

      metadata {
        annotations = {
          "prometheus.io/scrape" = "true"
        }
        labels = local.labels.kube_state_metrics
      }

      spec {
        service_account_name = kubernetes_service_account_v1.kube_state_metrics.metadata.0.name
        automount_service_account_token = true
        priority_class_name  = var.priority_class

        security_context {
          run_as_user  = var.user_id
          run_as_group = var.group_id
          fs_group     = var.group_id
        }

        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_expressions {
                  key      = "app.kubernetes.io/name"
                  operator = "In"
                  values   = [local.name.kube_state_metrics]
                }
                match_expressions {
                  key      = "app.kubernetes.io/instance"
                  operator = "In"
                  values   = [var.instance]
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }

        container {
          name              = "kube-state-metrics"
          image             = "${var.image_name.kube-state-metrics}:${var.image_tag.kube-state-metrics}"
          image_pull_policy = var.image_tag == "latest" ? "Always" : "IfNotPresent"

          dynamic "env" {
            for_each = merge(var.extra_env, {})
            content {
              name  = env.key
              value = env.value
            }
          }

          port {
            name           = "metrics"
            protocol       = "TCP"
            container_port = 8080
          }

          port {
            name           = "telemetry"
            protocol       = "TCP"
            container_port = 8081
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "256Mi"
            }
          }

          security_context {
            read_only_root_filesystem = true
            allow_privilege_escalation = false
          }

          readiness_probe {
            period_seconds        = 10
            initial_delay_seconds = 5
            success_threshold     = 1
            failure_threshold     = 3
            timeout_seconds       = 3

            http_get {
              scheme = "HTTP"
              path   = "/healthz"
              port   = "metrics"
            }
          }
        }

        dynamic "toleration" {
          for_each = {
            for toleration in var.tolerations : toleration["key"] => toleration
          }
          content {
            key      = toleration.key
            operator = toleration.value["operator"]
            value    = toleration.value["value"]
            effect   = toleration.value["effect"]
          }
        }

      }

    }

  }
  wait_for_rollout = var.wait_for_rollout
}

resource "kubernetes_service_account_v1" "kube_state_metrics" {
  metadata {
    name        = local.name.kube_state_metrics
    namespace   = var.namespace
    labels      = local.labels.kube_state_metrics
    annotations = var.service_account_annotations
  }

  dynamic "image_pull_secret" {
    for_each = { for image_pull_secret in var.image_pull_secrets : image_pull_secret => {} }
    content {
      name = image_pull_secret.key
    }
  }

}

resource "kubernetes_service_v1" "kube_state_metrics" {

  metadata {
    name        = local.name.kube_state_metrics
    namespace   = var.namespace
    annotations = var.service_annotations
    labels      = local.labels.kube_state_metrics
  }

  spec {
    type = "ClusterIP"

    port {
      name        = "metrics"
      protocol    = "TCP"
      port        = 8080
      target_port = "metrics"
    }

    port {
      name        = "telemetry"
      protocol    = "TCP"
      port        = 8081
      target_port = "telemetry"
    }

    selector = local.selector_labels.kube_state_metrics

  }

}

resource "kubernetes_cluster_role_v1" "kube_state_metrics" {

  metadata {
    name   = local.name.kube_state_metrics
    labels = local.labels.kube_state_metrics
  }

  rule {
    api_groups = [""]
    resources = [
      "configmaps",
      "secrets",
      "nodes",
      "pods",
      "services",
      "serviceaccounts",
      "resourcequotas",
      "replicationcontrollers",
      "limitranges",
      "persistentvolumeclaims",
      "persistentvolumes",
      "namespaces",
      "endpoints"
    ]
    verbs = [
      "list",
      "watch"
    ]
  }

  rule {
    api_groups = ["apps"]
    resources = [
      "statefulsets",
      "daemonsets",
      "deployments",
      "replicasets"
    ]
    verbs = [
      "list",
      "watch"
    ]
  }

  rule {
    api_groups = ["batch"]
    resources = [
      "cronjobs",
      "jobs"
    ]
    verbs = [
      "list",
      "watch"
    ]
  }

  rule {
    api_groups = ["autoscaling"]
    resources = [
      "horizontalpodautoscalers"
    ]
    verbs = [
      "list",
      "watch"
    ]
  }

  rule {
    api_groups = ["authentication.k8s.io"]
    resources = [
      "tokenreviews"
    ]
    verbs = [
      "create"
    ]
  }

  rule {
    api_groups = ["authorization.k8s.io"]
    resources = [
      "subjectaccessreviews"
    ]
    verbs = [
      "create"
    ]
  }

  rule {
    api_groups = ["authorization.k8s.io"]
    resources = [
      "subjectaccessreviews"
    ]
    verbs = [
      "create"
    ]
  }

  rule {
    api_groups = ["policy"]
    resources = [
      "poddisruptionbudgets"
    ]
    verbs = [
      "list",
      "watch"
    ]
  }

  rule {
    api_groups = ["certificates.k8s.io"]
    resources = [
      "certificatesigningrequests"
    ]
    verbs = [
      "list",
      "watch"
    ]
  }

  rule {
    api_groups = ["discovery.k8s.io"]
    resources = [
      "endpointslices"
    ]
    verbs = [
      "list",
      "watch"
    ]
  }

  rule {
    api_groups = ["storage.k8s.io"]
    resources = [
      "storageclasses",
      "volumeattachments"
    ]
    verbs = [
      "list",
      "watch"
    ]
  }

  rule {
    api_groups = ["admissionregistration.k8s.io"]
    resources = [
      "mutatingwebhookconfigurations",
      "validatingwebhookconfigurations"
    ]
    verbs = [
      "list",
      "watch"
    ]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources = [
      "networkpolicies",
      "ingressclasses",
      "ingresses"
    ]
    verbs = [
      "list",
      "watch"
    ]
  }

  rule {
    api_groups = ["coordination.k8s.io"]
    resources = [
      "leases"
    ]
    verbs = [
      "list",
      "watch"
    ]
  }


  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources = [
      "clusterrolebindings",
      "clusterroles",
      "rolebindings",
      "roles"
    ]
    verbs = [
      "list",
      "watch"
    ]
  }

}

resource "kubernetes_cluster_role_binding_v1" "kube_state_metrics" {

  metadata {
    name   = local.name.kube_state_metrics
    labels = local.labels.kube_state_metrics
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.kube_state_metrics.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.kube_state_metrics.metadata.0.name
    namespace = var.namespace
  }

}
