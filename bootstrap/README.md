# Kubeflow 1.3 bootstrapping

## Install

There are environment variables, which users can set in order to adjust Kubeflow installation and/or runtime behavior:

| Var name | Description | If var is not set | 
| - | - | - |
| `KF_JOBS_NS` | Determines in which namespace Kubeflow install jobs will be executed. Namespace with provided name will be created (if it's already exists it'll cause an error). | Kubeflow install jobs will be executed in `kubeflow-jobs` namespace. |
| `MANIFESTS_LOCATION` | The URI which points to location of Kubeflow manifest archive. | Installer will download file from `file:///opt/hpe/static/manifests.tar.gz`. This link points to archive inside docker container of Kubeflow installer job. |
| `DISABLE_ISTIO` | Accepts two values: `true` or `false`. If value is set to `false` - installer will install istio 1.9.0, otherwise - will not. | Default value is `false`, so installer will install istio. |
| `DISABLE_NOTEBOOKSERVERS_LINK` | Accepts two values: `true` or `false`. Determines if notebook servers link will be disabled on Kubeflow dashboard. So in case of `true` value notebook servers link will not be shown on the Kubeflow central dashboard UI. | Default value is `false`, so notebook servers link will be displayed on the UI. |
| `AIRGAP_REGISTRY` | Determines if docker images, which is used by Kubeflow ecosystem (except of images, which are defined in Kubeflow pipelines), should be downloaded from airgap docker registry (e.g. in case of connection to Internet couldn't be established). Example value: `localhost:5000/` (Trailing slash is needed). | Default value is empty string, so all images (except of images, which are defined in Kubeflow pipelines) will be pulled from the Internet. |
| `USER_AIRGAP_REGISTRY` | Determines if docker images, which are defined in workflows, which are handled by Kubeflow pipelines, should be downloaded from some another airgap docker registry or Internet (e.g. in case of user doesn't control the `AIRGAP_REGISTRY` registry and there is another registry controlled by user, or those images of KFP workflows should be pulled from Internet). Example value: `localhost:5000/` (Trailing slash is needed). | This variable will be equal to the value of `AIRGAP_REGISTRY` env variable. If user want to set empty string (in order to pull images, which are defined in pipelines, from the Internet), they need to explicitly set this environment variable with value which should equals empty string. |
| `http_proxy`, `https_proxy` | Set proxy variables for installer in order to download manifests archive through proxy. | Will not use proxy in order to establish Internet connection. |
| `TLS_SECRET_NAME`, `TLS_SECRET_NS` | If during Kubeflow installation env variable `MANIFESTS_LOCATION` is set and manifests archive is located on server with custom self-signed cert, it is needed to specify TLS key and certificate for installer job. If on the current Kubernetes cluster tls secret with key and cert of server is already exists, you should pass its name into `TLS_SECRET_NAME` env variable and its namespace into `TLS_SECRET_NS` env variable. So in order to download manifests archive from host with self-signed cert, user need to pass non-empty valid k8s tls secret's name and its namespace in appropriate env variables. | If these vars are not set and also `TLS_CERT_LOCATION`, `TLS_KEY_LOCATION` vars are not set too, manifests archive will be downloaded using global trusted certificates and authorities. |
| `TLS_CERT_LOCATION`, `TLS_KEY_LOCATION` | If during Kubeflow installation env variable `MANIFESTS_LOCATION` is set and manifests archive is located on server with custom self-signed cert, it is needed to specify TLS key and certificate for installer job. If you know locations (file paths) of TLS key and certificate files on your machine, you should pass the file path of TLS certificate into `TLS_CERT_LOCATION` env variable and also you need to pass the file path of TLS key into `TLS_KEY_LOCATION` env variable. Both these env variables should be valid file path and these files must be readable. So in order to download manifests archive from host with self-signed cert, user need to pass file paths of TLS certificate and key in appropriate env variables. | If these vars are not set and also `TLS_SECRET_NAME`, `TLS_SECRET_NS` vars are not set too, manifests archive will be downloaded using global trusted certificates and authorities. |

### How to install Kubeflow:

1. Set all needed environment variables

2. Execute such script: `./bootstrap/install.sh`

You can also set env variables directly in the command just in the beginning, for example: `DISABLE_ISTIO=true MANIFESTS_LOCATION=https://example.com/manifest.tar.gz ./bootstrap/install.sh`

## Uninstall

In order to uninstall Kubeflow you need to set such environment variables with values, which were used during Kubeflow installation. Only such env variables make sense for uninstall script:

* `KF_JOBS_NS`
* `MANIFESTS_LOCATION`
* `DISABLE_ISTIO`

### How to uninstall Kubeflow:

1. Set all needed environment variables

2. Execute such script: `./bootstrap/uninstall.sh`

You can also set env variables directly in the command just in the beginning, for example: `DISABLE_ISTIO=true MANIFESTS_LOCATION=https://example.com/manifest.tar.gz ./bootstrap/uninstall.sh`
