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
      replicas: 1
      service:
        type: LoadBalancer
        port: 80
        targetPort: 3000
        externalTrafficPolicy: Cluster
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
        serviceMonitorSelectorNilUsesHelmValues: false
        podMonitorNamespaceSelector: {}
        podMonitorSelector: {}
        podMonitorSelectorNilUsesHelmValues: false
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