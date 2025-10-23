resource "kubernetes_namespace" "monitoring" {
  metadata { name = "monitoring" }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "58.7.2"

  values = [<<-YAML
    grafana:
      adminPassword: "${var.adminPassword}"
      service:
        type: ClusterIP
      defaultDashboardsEnabled: true
      persistence:
        enabled: false

    prometheus:
      service:
        type: ClusterIP
      prometheusSpec:
        retention: 3d
        serviceMonitorNamespaceSelector: {}
        serviceMonitorSelector: {}         
        podMonitorNamespaceSelector: {}     
        podMonitorSelector: {}                
        ruleNamespaceSelector: {}
        ruleSelector: {}
        resources:
          requests:
            cpu: "200m"
            memory: "512Mi"
          limits:
            cpu: "500m"
            memory: "1Gi"

    alertmanager:
      enabled: true
      alertmanagerSpec:
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
    YAML
  ]
}

resource "helm_release" "kubecost" {
  name       = "kubecost"
  repository = "https://kubecost.github.io/cost-analyzer/"
  chart      = "cost-analyzer"
  version    = "2.0.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  depends_on = [helm_release.kube_prometheus_stack]

  timeout        = 1200
  wait           = true
  atomic         = true
  wait_for_jobs  = true

  values = [<<-YAML
    global:
      grafana:
        enabled: false

    kubecostProductConfigs:
      clusterName: "oke-demo"

    prometheus:
      enabled: false
    prometheusConfig:
      internal:
        enabled: false
      external:
        enabled: true
        url: "http://kube-prometheus-stack-prometheus:9090"

    serviceMonitor:
      enabled: true
    podMonitor:
      enabled: true

    cost-analyzer:
      service:
        type: ClusterIP
  YAML
  ]
}