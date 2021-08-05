#! /bin/bash

DATA_VOLUME="$3"
DATA_MNT_PATH="/data"


NAMESPACE="$1"
NOTEBOOK="$2"
JOVYAN_USER="7000"
USERS_GROUP="8000"


#JOVYAN_USER="1000"
#USERS_GROUP="100"

if [ -z "$NAMESPACE" ] || [ -z "$NOTEBOOK" ] || [ -z "$DATA_VOLUME" ]; then
    echo "Enter namespace, notebook_name and data-volume as parameters"
    echo "./notebook-patch.sh nkili test-1 dat-vol-1"
    exit 1
fi

STATEFULSET="$NOTEBOOK"

# Fetching volume name
PVC_NAME=$(kubectl -n $NAMESPACE get notebook/$NOTEBOOK -o jsonpath='{.spec.template.spec.volumes[0].name}')

# Create a patch file to insert initContainer
PATCH_DATA="[{
    \"command\": [
        \"sh\",
        \"-c\",
        \"chown -R $JOVYAN_USER:$USERS_GROUP /mnt/vol; chown -R $JOVYAN_USER:$USERS_GROUP $DATA_MNT_PATH; \"
    ],
    \"image\": \"busybox\",
    \"name\": \"change-vol-perms\",
    \"volumeMounts\": [
        {
            \"mountPath\": \"/mnt/vol\",
            \"name\": \"$PVC_NAME\"
        },
        {
            \"mountPath\": \"$DATA_MNT_PATH\",
            \"name\": \"$DATA_VOLUME\"
        }
    ]}]"

patch_op="[ {\"op\":\"add\", \"path\": \"/spec/template/spec/initContainers\", \"value\" : $PATCH_DATA} ]"
kubectl -n $NAMESPACE patch notebook/$NOTEBOOK --type=json --patch "$patch_op"

PATCH_DATA="{
    \"runAsUser\": $JOVYAN_USER,
    \"runAsGroup\": $USERS_GROUP
    }"

patch_op="[ {\"op\":\"add\", \"path\": \"/spec/template/spec/containers/0/securityContext\", \"value\" : $PATCH_DATA} ]"
kubectl -n $NAMESPACE patch notebook/$NOTEBOOK --type=json --patch "$patch_op"

kubectl -n $NAMESPACE delete statefulset/$STATEFULSET
