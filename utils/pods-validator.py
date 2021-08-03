import sys
from kubernetes import client, config

pods_templates = [
    "authservice-",
    "cluster-local-",
    "istio-citadel-",
    "istio-galley-",
    "istio-ingressgateway-",
    "istio-nodeagent-",
    "istio-pilot-",
    "istio-policy-",
    "istio-security-post-install-",
    "istio-sidecar-injector-",
    "istio-telemetry-",
    "kfserving-ingressgateway-",
    "prometheus-",
    "admission-webhook-deployment-",
    "application-controller-stateful-set-",
    "argo-ui-",
    "centraldashboard-",
    "jupyter-web-app-deployment-",
    "katib-controller-",
    "katib-db-manager-",
    "katib-mysql-",
    "katib-ui-",
    "kfserving-controller-manager-",
    "minio-",
    "ml-pipeline-ml-pipeline-visualizationserver-",
    "ml-pipeline-persistenceagent-",
    "ml-pipeline-scheduledworkflow-",
    "ml-pipeline-ui-",
    "ml-pipeline-viewer-controller-deployment-",
    "ml-pipeline-",
    "mysql-",
    "notebook-controller-deployment-",
    "profiles-deployment-",
    "pytorch-operator-",
    "seldon-controller-manager-",
    "spartakus-volunteer-",
    "tf-job-operator-",
    "workflow-controller-",
    "dex-"
]

config.load_kube_config()
v1 = client.CoreV1Api()

pod_list = v1.list_namespaced_pod("istio-system")
pods = pod_list.items
pod_list = v1.list_namespaced_pod("kubeflow")
pods.extend(pod_list.items)
pod_list = v1.list_namespaced_pod("auth")
pods.extend(pod_list.items)
for pod in pods:
    name = pod.metadata.name
    status = pod.status.phase
    if status == 'Succeeded' or (status == 'Running' and pod.status.container_statuses[0].ready):
        for template in pods_templates:
            if name.startswith(template):
                pods_templates.remove(template)
                break

sys.exit(len(pods_templates))
