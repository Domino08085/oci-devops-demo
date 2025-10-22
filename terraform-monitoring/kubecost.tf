resource "kubernetes_namespace" "kubecost" {
  metadata { name = "kubecost" }
}

resource "helm_release" "kubecost" {
  name       = "kubecost"
  repository = "https://kubecost.github.io/cost-analyzer/"
  chart      = "cost-analyzer"
  version    = "2.0.0"
  namespace  = kubernetes_namespace.kubecost.metadata[0].name

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
        url: "http://prometheus-operated.monitoring.svc:9090"
    cost-analyzer:
      service:
        type: LoadBalancer
    YAML
  ]
}
