#! /bin/bash

function oc::wait::object::availability() {
    local cmd=$1 # Command whose output we require
    local interval=$2 # How many seconds to sleep between tries
    local iterations=$3 # How many times we attempt to run the command

    ii=0

    while [ $ii -le $iterations ]
    do

        token=$($cmd) && returncode=$? || returncode=$?
        if [ $returncode -eq 0 ]; then
            break
        fi

        ((ii=ii+1))
        if [ $ii -eq 100 ]; then
            echo $cmd "did not return a value"
            exit 1
        fi
        sleep $interval
    done
    echo $token
}


MODELMESH_PROJECT=${1:-"opendatahub"}
INFERENCE_SERVICE_PROJECT=${2:-"mesh-test"}

oc new-project $MODELMESH_PROJECT
sed -i "s/<namespace>/${MODELMESH_PROJECT}/g" ../manifests/kfdef.yaml
oc apply -f ../manifests/kfdef.yaml -n $MODELMESH_PROJECT

oc new-project $INFERENCE_SERVICE_PROJECT
oc label namespace $INFERENCE_SERVICE_PROJECT "modelmesh-enabled=true" --overwrite=true || echo "Failed to apply modelmesh-enabled label."

echo "Waiting for kserve crds to be created by the Operator"
oc::wait::object::availability "oc get crd inferenceservices.serving.kserve.io" 5 120
oc::wait::object::availability "oc get crd predictors.serving.kserve.io" 5 120
oc::wait::object::availability "oc get crd servingruntimes.serving.kserve.io" 5 120

oc apply -f sample-minio.yaml -n $INFERENCE_SERVICE_PROJECT
oc apply -f openvino-inference-service.yaml -n $INFERENCE_SERVICE_PROJECT
oc apply -f openvino-serving-runtime.yaml -n $INFERENCE_SERVICE_PROJECT

oc apply -f service_account.yaml -n $INFERENCE_SERVICE_PROJECT