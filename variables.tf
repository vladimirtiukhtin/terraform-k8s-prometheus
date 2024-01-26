variable "name" {
  description = "Common application name"
  type        = string
  default     = "prometheus"
}

variable "instance" {
  description = "Common instance name"
  type        = string
  default     = "default"
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "default"
}

variable "replicas" {
  description = "Number of cluster nodes. Recommended value is the one which equals number of kubernetes nodes"
  type = object({
    prometheus-server        = number
    prometheus-alert-manager = number
    prometheus-k8s-adapter   = number
    prometheus-node-exporter = number
    kube-state-metrics       = number
  })
  default = {
    prometheus-server        = 1
    prometheus-alert-manager = 1
    prometheus-k8s-adapter   = 1
    prometheus-node-exporter = 1
    kube-state-metrics       = 1
  }
}

variable "user_id" {
  description = "Unix UID to run the process with and to apply to persistent volume"
  type        = number
  default     = 65534
}

variable "group_id" {
  description = "Unix GID to run the process with and to apply to persistent volume"
  type        = number
  default     = 65534
}

variable "image_name" {
  description = "Container image name including registry address"
  type = object({
    prometheus-server        = string
    prometheus-alert-manager = string
    prometheus-k8s-adapter   = string
    prometheus-node-exporter = string
    kube-state-metrics       = string
  })
  default = {
    prometheus-server        = "prom/prometheus"
    prometheus-alert-manager = "prom/alertmanager"
    prometheus-k8s-adapter   = "registry.k8s.io/prometheus-adapter/prometheus-adapter"
    prometheus-node-exporter = ""
    kube-state-metrics       = "registry.k8s.io/kube-state-metrics/kube-state-metrics"
  }
}

variable "image_tag" {
  description = "Container image tag (version)"
  type = object({
    prometheus-server        = string
    prometheus-alert-manager = string
    prometheus-k8s-adapter   = string
    prometheus-node-exporter = string
    kube-state-metrics       = string
  })
  default = {
    prometheus-server        = "v2.47.0"
    prometheus-alert-manager = "v0.26.0"
    prometheus-k8s-adapter   = "v0.11.1"
    prometheus-node-exporter = "1.6.1"
    kube-state-metrics       = "v2.10.1"
  }
}

variable "image_pull_secrets" {
  description = "List of existing image pull secrets to attach to a service account"
  type        = list(string)
  default     = []
}

variable "service_account_annotations" {
  description = ""
  type        = map(string)
  default     = {}
}

variable "statefulset_annotations" {
  description = "Annotations to apply to StatefulSet"
  type        = map(string)
  default     = null
}

variable "service_annotations" {
  description = ""
  type        = map(any)
  default     = {}
}

variable "storage_class" {
  description = ""
  type        = string
  default     = null
}

variable "storage_path" {
  description = ""
  type        = string
  default     = "/var/lib/prometheus"
}

variable "storage_size" {
  description = ""
  type        = string
  default     = "16Gi"
}

variable "node_affinity" {
  description = ""
  type = object({
    kind  = string
    label = string
    value = string
  })
  default = null
}

variable "tolerations" {
  description = "List of node taints a pod tolerates"
  type = list(object({
    key      = optional(string)
    operator = optional(string, null)
    value    = optional(string, null)
    effect   = optional(string, null)
  }))
  default = []
}

variable "priority_class" {
  description = ""
  type        = string
  default     = "system-cluster-critical"
}

variable "extra_env" {
  description = "Any extra environment variables to apply to MySQL StatefulSet"
  type        = map(string)
  default     = {}
}

variable "extra_labels" {
  description = "Any extra labels to apply to kubernetes resources"
  type        = map(string)
  default     = {}
}

variable "wait_for_rollout" {
  description = "Whether to wait kubernetes readiness prove to succeed"
  type        = bool
  default     = true
}
