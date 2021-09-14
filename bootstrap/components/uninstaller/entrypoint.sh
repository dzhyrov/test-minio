#!/bin/sh
# set -e

KF_JOBS_NS=${KF_JOBS_NS:-kubeflow-jobs}
MANIFESTS_DIR=manifests
CURRENT_DIR=$(pwd)

DISABLE_ISTIO=${DISABLE_ISTIO:-false}
MANIFESTS_LOCATION=${MANIFESTS_LOCATION:-"file://${CURRENT_DIR}/static/manifests.tar.gz"}

test_env_vars()
{
    local ret_val=0

    if [ ${DISABLE_ISTIO} != true -a ${DISABLE_ISTIO} != false ]; then
        echo 'DISABLE_ISTIO should be unset or set to either "true" or "false".'
        ret_val=1
    fi

    return $ret_val
}

delete_cert_manager()
{
    ./kustomize build ${MANIFESTS_DIR}/common/cert-manager/cert-manager/overlays/self-signed | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/common/cert-manager/cert-manager-crds/base | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/common/cert-manager/cert-manager-kube-system-resources/base | kubectl delete -f -
}

delete_istio()
{
    ./kustomize build ${MANIFESTS_DIR}/common/istio-1-9-0/istio-install/base | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/common/istio-1-9-0/istio-namespace/base | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/common/istio-1-9-0/istio-crds/base | kubectl delete -f -
}

delete_authservices()
{
    ./kustomize build ${MANIFESTS_DIR}/common/dex/overlays/istio | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/common/oidc-authservice/base | kubectl delete -f -
}

delete_knative()
{
    ./kustomize build ${MANIFESTS_DIR}/common/knative/knative-eventing/overlays/image-pull-secret | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/bootstrap/components/image-pull-secret/knative-eventing | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/common/knative/knative-serving/base | kubectl delete -f -
}

delete_cluster_local_gateway()
{
    ./kustomize build ${MANIFESTS_DIR}/common/istio-1-9-0/cluster-local-gateway/base | kubectl delete -f -
}

delete_prism()
{
    ./kustomize build ${MANIFESTS_DIR}/apps/prism/base | kubectl delete -f -
}

delete_kf_services()
{
    MANIFESTS_DIR=$0
    ./kustomize build ${MANIFESTS_DIR}/contrib/seldon/seldon-core-operator/overlays/application | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/contrib/application/application-crds/base | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/common/user-namespace/base | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/xgboost-job/upstream/overlays/kubeflow | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/mxnet-job/upstream/overlays/kubeflow | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/mpi-job/upstream/overlays/kubeflow | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/pytorch-job/upstream/overlays/kubeflow | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/tf-training/upstream/overlays/kubeflow | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/tensorboard/tensorboards-web-app/upstream/overlays/istio | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/tensorboard/tensorboard-controller/upstream/overlays/kubeflow | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/volumes-web-app/upstream/overlays/istio | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/profiles/upstream/overlays/kubeflow | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/jupyter/notebook-controller/upstream/overlays/kubeflow | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/jupyter/jupyter-web-app/upstream/overlays/istio | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/admission-webhook/upstream/overlays/cert-manager | kubectl delete -f -
    # deleting is independent from disabling notebook server links
    ./kustomize build ${MANIFESTS_DIR}/apps/centraldashboard/upstream/overlays/istio | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/katib/upstream/installs/katib-with-kubeflow | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/kfserving/upstream/overlays/kubeflow | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/pipeline/upstream/third-party/minio-console/base | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/pipeline/upstream/third-party/minio/options/istio | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/pipeline/upstream/third-party/minio/overlays/ldap | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/pipeline/upstream/overlays/image-pull-secret | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/apps/pipeline/upstream/cluster-scoped-resources | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/common/istio-1-9-0/kubeflow-istio-resources/base | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/common/kubeflow-roles/base | kubectl delete -f -
    ./kustomize build ${MANIFESTS_DIR}/common/kubeflow-namespace/base | kubectl delete -f -
    return 0
}

delete_kf_url()
{
    ./kustomize build ${MANIFESTS_DIR}/bootstrap/components/hpecpconfig-patch | kubectl delete -f - -n ${KF_JOBS_NS}
}

if test_env_vars; then
    if [ -r /usr/share/ca-certificates/kf-jobs/kf-jobs-tls.crt ]; then
        update-ca-certificates
        curl --cacert /usr/share/ca-certificates/kf-jobs/kf-jobs-tls.crt -Lo ${MANIFESTS_DIR}.tar.gz ${MANIFESTS_LOCATION}
    else
        curl -Lo ${MANIFESTS_DIR}.tar.gz ${MANIFESTS_LOCATION}
    fi
    
    mkdir manifests
    if tar -xf ${MANIFESTS_DIR}.tar.gz -C ${MANIFESTS_DIR} --strip-components 1; then
        printf "\nManifests downloaded successfully\n\n"
    else
        printf "\nManifests download failed\n\n"
        exit 1
    fi

    unset http_proxy
    unset https_proxy

    ./kustomize build ${MANIFESTS_DIR}/bootstrap/components/installer | kubectl delete -f - -n ${KF_JOBS_NS} --ignore-not-found

    delete_kf_url
    printf "\nDeleting prism...\n\n"
    delete_prism
    printf "\nTrying to delete kubeflow services...\n\n"
    export -f delete_kf_services
    while ! timeout -s SIGINT 4m bash -c delete_kf_services ${MANIFESTS_DIR}; do printf "\n*** Retrying to delete kubeflow services... ***\n\n"; done

    if [ ${DISABLE_ISTIO} != true ]; then
        printf "\nTrying to delete cluster local gateway...\n\n"
        delete_cluster_local_gateway
    fi

    printf "\nTrying to delete knative...\n\n"
    delete_knative

    printf "\nTrying to delete authservices...\n\n"
    delete_authservices

    if [ ${DISABLE_ISTIO} != true ]; then
        printf "\nTrying to delete istio...\n\n"
        delete_istio
    fi

    printf "\nTrying to delete cert manager...\n\n"
    delete_cert_manager

    ./kustomize build ${MANIFESTS_DIR}/bootstrap/components/dex-secret-ldap | kubectl delete -f - -n ${KF_JOBS_NS}
    ./kustomize build ${MANIFESTS_DIR}/bootstrap/components/minio-config | kubectl delete -f - -n ${KF_JOBS_NS}
    
    echo "kubeflow uninstall script finished done."
    exit 0
else
    echo "kubeflow uninstall script failed."
    exit 1
fi
