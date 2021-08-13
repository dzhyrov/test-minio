FROM bitnami/kubectl:1.21

USER root

WORKDIR /opt/hpe
RUN mkdir static

COPY kustomize kustomize
COPY manifests.tar.gz static/manifests.tar.gz
