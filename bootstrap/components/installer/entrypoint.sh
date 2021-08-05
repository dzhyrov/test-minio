#!/bin/sh
set -e

KF_JOBS_NS=${KF_JOBS_NS:-kubeflow-jobs}
RETRY_TIMEOUT=8
MAX_RETRIES=8
MANIFESTS_DIR=manifests
CURRENT_DIR=$(pwd)
EXTERNAL_MINIO_SECRET_NAME=kubeflow-external-minio
EXTERNAL_MINIO_SECRET_NAMESPACE=kubeflow-minio

DISABLE_ISTIO=${DISABLE_ISTIO:-false}
DISABLE_NOTEBOOKSERVERS_LINK=${DISABLE_NOTEBOOKSERVERS_LINK:-false}
MANIFESTS_LOCATION=${MANIFESTS_LOCATION:-"file://${CURRENT_DIR}/static/manifests.tar.gz"}

test_env_vars()
{
    local ret_val=0

    if [ ${DISABLE_NOTEBOOKSERVERS_LINK} != true -a ${DISABLE_NOTEBOOKSERVERS_LINK} != false ]; then
      echo 'DISABLE_NOTEBOOKSERVERS_LINK should be unset or set to either "true" or "false".'
      ret_val=1
    fi

    if [ ${DISABLE_ISTIO} != true -a ${DISABLE_ISTIO} != false ]; then
        echo 'DISABLE_ISTIO should be unset or set to either "true" or "false".'
        ret_val=1
    fi

    return $ret_val
}

deploy_cert_manager()
{
    ./kustomize build ${MANIFESTS_DIR}/common/cert-manager/cert-manager-kube-system-resources/base | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/common/cert-manager/cert-manager-crds/base | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/common/cert-manager/cert-manager/overlays/self-signed | kubectl apply -f -
}

deploy_istio()
{
    ./kustomize build ${MANIFESTS_DIR}/common/istio-1-9-0/istio-crds/base | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/common/istio-1-9-0/istio-namespace/base | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/common/istio-1-9-0/istio-install/base | kubectl apply -f -
}

deploy_authservices()
{
    ./kustomize build ${MANIFESTS_DIR}/common/oidc-authservice/base | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/common/dex/overlays/istio | kubectl apply -f -
}

deploy_knative()
{
    ./kustomize build ${MANIFESTS_DIR}/common/knative/knative-serving-crds/base | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/common/knative/knative-serving-install/base | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/common/knative/knative-eventing-crds/base | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/common/knative/knative-eventing-install/base | kubectl apply -f -
}

deploy_cluster_local_gateway()
{
    ./kustomize build ${MANIFESTS_DIR}/common/istio-1-9-0/cluster-local-gateway/base | kubectl apply -f -
}

deploy_kf_services()
{
    ./kustomize build ${MANIFESTS_DIR}/common/kubeflow-namespace/base | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/bootstrap/components/image-pull-secret/kubeflow | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/common/kubeflow-roles/base | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/common/istio-1-9-0/kubeflow-istio-resources/base | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/apps/pipeline/upstream/overlays/image-pull-secret | kubectl apply -f - && \
    
    kubectl get secret -n ${EXTERNAL_MINIO_SECRET_NAMESPACE} ${EXTERNAL_MINIO_SECRET_NAME} --ignore-not-found | grep . > /dev/null || {
        ./kustomize build ${MANIFESTS_DIR}/apps/pipeline/upstream/third-party/minio/base | kubectl apply -f -
        ./kustomize build ${MANIFESTS_DIR}/apps/pipeline/upstream/third-party/minio/options/istio | kubectl apply -f -
    }
    
    ./kustomize build ${MANIFESTS_DIR}/apps/kfserving/upstream/overlays/kubeflow | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/apps/katib/upstream/installs/katib-with-kubeflow | kubectl apply -f -
    
    if [ ${DISABLE_NOTEBOOKSERVERS_LINK} = false ]; then
        ./kustomize build ${MANIFESTS_DIR}/apps/centraldashboard/upstream/overlays/istio | kubectl apply -f -
    else
        ./kustomize build ${MANIFESTS_DIR}/apps/centraldashboard/upstream/overlays/disableNotebookServers | kubectl apply -f -
    fi

    ./kustomize build ${MANIFESTS_DIR}/apps/admission-webhook/upstream/overlays/cert-manager | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/apps/jupyter/jupyter-web-app/upstream/overlays/istio | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/apps/jupyter/notebook-controller/upstream/overlays/kubeflow | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/apps/profiles/upstream/overlays/kubeflow | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/apps/volumes-web-app/upstream/overlays/istio | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/apps/tensorboard/tensorboards-web-app/upstream/overlays/istio | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/apps/tf-training/upstream/overlays/kubeflow | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/apps/pytorch-job/upstream/overlays/kubeflow | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/apps/mpi-job/upstream/overlays/kubeflow | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/apps/mxnet-job/upstream/overlays/kubeflow | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/apps/xgboost-job/upstream/overlays/kubeflow | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/common/user-namespace/base | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/contrib/application/application-crds/base | kubectl apply -f - && \
    ./kustomize build ${MANIFESTS_DIR}/contrib/seldon/seldon-core-operator/overlays/application | kubectl apply -f -
}

install()
{    
    printf "\nTrying to deploy cert manager...\n\n"
    while ! deploy_cert_manager; do printf "\n*** Retrying to deploy cert manager... ***\n\n"; sleep ${RETRY_TIMEOUT}; done

    if [ ${DISABLE_ISTIO} != true ]; then
        printf "\nTrying to deploy istio...\n\n"
        while ! deploy_istio; do printf "\n*** Retrying to deploy istio... ***\n\n"; sleep ${RETRY_TIMEOUT}; done
    fi

    printf "\nTrying to deploy authservices...\n\n"
    while ! deploy_authservices; do printf "\n*** Retrying to deploy authservices... ***\n\n"; sleep ${RETRY_TIMEOUT}; done

    printf "\nTrying to deploy knative...\n\n"
    while ! deploy_knative; do printf "\n*** Retrying to deploy knative... ***\n\n"; sleep ${RETRY_TIMEOUT}; done

    if [ ${DISABLE_ISTIO} != true ]; then
        printf "\nTrying to deploy cluster local gateway...\n\n"
        while ! deploy_cluster_local_gateway; do printf "\n*** Retrying to deploy cluster local gateway... ***\n\n"; sleep ${RETRY_TIMEOUT}; done
    fi

    printf "\nTrying to deploy kubeflow services...\n\n"
    cur_retries=0
    while ! deploy_kf_services; do
        cur_retries=$((cur_retries+1))
        if (( cur_retries > MAX_RETRIES )); then
            printf "\n*** KF deploy failed ***\n\n"
        fi
        printf "\n*** Retrying to deploy kubeflow services... ***\n\n"; sleep ${RETRY_TIMEOUT};
    done
}

if test_env_vars; then
    curl -Lo ${MANIFESTS_DIR}.tar.gz ${MANIFESTS_LOCATION}
    mkdir manifests
    if tar -xf ${MANIFESTS_DIR}.tar.gz -C ${MANIFESTS_DIR} --strip-components 1; then
        printf "\nManifests downloaded successfully\n\n"
    else
        printf "\nManifests download failed\n\n"
        exit 1
    fi
    unset http_proxy
    unset https_proxy
    ./kustomize build ${MANIFESTS_DIR}/bootstrap/components/minio-config | kubectl apply -f - -n ${KF_JOBS_NS}
    ./kustomize build ${MANIFESTS_DIR}/bootstrap/components/dex-secret-ldap | kubectl apply -f - -n ${KF_JOBS_NS}
    install
    echo "kubeflow install script finished done"
    exit 0
else
    echo "kubeflow install script failed."
    exit 1
fi
