#!/bin/sh
set -e

KF_JOBS_NS=${KF_JOBS_NS:-kubeflow-jobs}
BASEDIR=$(dirname "$0")
MANIFESTS_LOCATION=${MANIFESTS_LOCATION:-"file:///opt/hpe/static/manifests.tar.gz"}

kubectl create ns ${KF_JOBS_NS}
kubectl apply -k ${BASEDIR}/components/image-pull-secret/jobs -n ${KF_JOBS_NS}
kubectl apply -k ${BASEDIR}/components/installer -n ${KF_JOBS_NS}
