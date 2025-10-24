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
        type: LoadBalancer
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