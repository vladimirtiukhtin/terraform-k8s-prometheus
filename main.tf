terraform {
  required_version = ">=1.3.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.0"
    }
  }

}

locals {
  name = {
    prometheus_server        = var.instance == "default" ? "prometheus-server" : "prometheus-server-${var.instance}"
    prometheus_alert_manager = var.instance == "default" ? "prometheus-alert-manager" : "prometheus-alert-manager-${var.instance}"
    prometheus_k8s_adapter   = var.instance == "default" ? "prometheus-k8s-adapter" : "prometheus-k8s-adapter-${var.instance}"
    prometheus_node_exporter = var.instance == "default" ? "prometheus-node-exporter" : "prometheus-node-exporter-${var.instance}"
    kube_state_metrics       = var.instance == "default" ? "kube-state-metrics" : "kube-state-metrics-${var.instance}"
  }
  selector_labels = {
    prometheus_server = {
      "app.kubernetes.io/name"     = "prometheus-server"
      "app.kubernetes.io/instance" = var.instance
    }
    prometheus_alert_manager= {
      "app.kubernetes.io/name"     = "prometheus-alert-manager"
      "app.kubernetes.io/instance" = var.instance
    }
    prometheus_k8s_adapter = {
      "app.kubernetes.io/name"     = "prometheus-k8s-adapter"
      "app.kubernetes.io/instance" = var.instance
    }
    prometheus_node_exporter = {
      "app.kubernetes.io/name"     = "prometheus-node-exporter"
      "app.kubernetes.io/instance" = var.instance
    }
    kube_state_metrics = {
      "app.kubernetes.io/name"     = "kube-state-metrics"
      "app.kubernetes.io/instance" = var.instance
    }
  }
  labels = {
    prometheus_server        = merge(local.common_labels, var.extra_labels, local.selector_labels.prometheus_server)
    prometheus_alert_manager = merge(local.common_labels, var.extra_labels, local.selector_labels.prometheus_alert_manager)
    prometheus_k8s_adapter   = merge(local.common_labels, var.extra_labels, local.selector_labels.prometheus_k8s_adapter)
    prometheus_node_exporter = merge(local.common_labels, var.extra_labels, local.selector_labels.prometheus_node_exporter)
    kube_state_metrics       = merge(local.common_labels, var.extra_labels, local.selector_labels.kube_state_metrics)
  }
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
  }
}
