import time
import os
from kubernetes import client, config
import base64
import sys
import json

minio_secret_name = "minio-params"
minio_secret_namespace = "kubeflow"
general_minio_secret_name = os.environ["EXTERNAL_MINIO_CONFIG_SECRET_NAME"] if "EXTERNAL_MINIO_CONFIG_SECRET_NAME" in os.environ and os.environ["EXTERNAL_MINIO_CONFIG_SECRET_NAME"] else "kubeflow-external-minio"
general_minio_secret_namespace = os.environ["EXTERNAL_MINIO_CONFIG_SECRET_NAMESPACE"] if "EXTERNAL_MINIO_CONFIG_SECRET_NAMESPACE" in os.environ and os.environ["EXTERNAL_MINIO_CONFIG_SECRET_NAMESPACE"] else "kubeflow-minio"

required_fields = ["host", "port", "secure", "accesskey", "secretkey"]
default_config_file_name = "default_config.json"

def b64encode(source : str) -> str:
    return base64.b64encode(source.encode('ascii')).decode('ascii')

__location__ = os.path.realpath(os.path.join(os.getcwd(), os.path.dirname(__file__)))
minio_default_config_location = os.path.join(__location__, default_config_file_name)

try:
    config.load_kube_config()
except:
    # load_kube_config throws if there is no config, but does not document what it throws, so I can't rely on any particular type here
    config.load_incluster_config()

v1 = client.CoreV1Api()

print("Reading secret", general_minio_secret_name, "from namespace", general_minio_secret_namespace)

try:
    secret = v1.read_namespaced_secret(name = general_minio_secret_name, namespace = general_minio_secret_namespace)
    data = secret.data
    for field in required_fields:
        if field not in data or not data[field]:
            sys.exit("Secret was read successfully, but is invalid. Missing field \"" + field + "\"")
    print("Secret valid!")
except client.exceptions.ApiException as err:
    if err.status != 404:
        print("Unexpected error while connecting to kubernetes")
        sys.exit(err)
    print("Secret was not found. Setting to use the default minio...")
    try:
        with open(minio_default_config_location, 'r') as template:
            data = json.load(template)
    except Exception as err:
        sys.exit("Error while opening default minio config" + err)
    
    for field in data.keys():
        data[field] = b64encode(data[field])

print("Trying to create kubeflow minio params secret...")
try:
    v1.create_namespaced_secret(
        namespace=minio_secret_namespace,
        body=client.V1Secret(
            metadata=client.V1ObjectMeta(
                name=minio_secret_name,
            ),
            type="Opaque",
            data=data
        )
    )
except client.exceptions.ApiException as err:
    sys.exit("Error while creating secret: " + str(err))

print("Success!")
