#!/bin/bash

source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/utils.sh"

BASE_HOME=/tmp
DIR_NAME=modelmesh
POSTFIX=$(date  "+%Y%m%d%m%s")

if [[ -f  $SCRIPT_DIR/.temp_new_modelmesh_manifests ]]; then
 FULL_DIR_NAME=$(cat $SCRIPT_DIR/.temp_new_modelmesh_manifests)
else
  FULL_DIR_NAME="$DIR_NAME-$POSTFIX"
  echo ${FULL_DIR_NAME} > $SCRIPT_DIR/.temp_new_modelmesh_manifests
fi 

TARGET_DIR=${BASE_HOME}/${FULL_DIR_NAME}

MODELMESH_CONTROLLER_BRANCH=main
MODELMESH_CONTROLLER_GIT=https://github.com/opendatahub-io/modelmesh-serving.git
MODELMESH_CONTROLLER_DIR=${TARGET_DIR}/model-mesh_templates/odh-modelmesh-controller

info "Generate opendatahub manifest in the ${TARGET_DIR}"
echo "TARGET DIR: ${TARGET_DIR}"
echo "--------------------------------------------------"
echo 


if [[ ! -d ${TARGET_DIR} ]]; then
  echo -n ".. Creating a ${TARGET_DIR} folder"
  mkdir -p ${TARGET_DIR}
else
  echo -n ".. ${TARGET_DIR} folder exist, it will reuse the existing folder"
fi
echo -e "\r ✓"
cd ${TARGET_DIR}

if [[ ! -d ${TARGET_DIR}/model-mesh_templates ]]; then
  echo -n ".. Copying the model-mesh_templates to ${TARGET_DIR} folder"
  cp -R $ODH_MANIFESTS_DIR/model-mesh_templates ${TARGET_DIR}/
else
  echo -n ".. model-mesh_template folder exist, it will reuse the existing folder"
fi
echo -e "\r ✓"


if [[ ! -d ${TARGET_DIR}/odh-modelmesh-controller ]]; then
  echo -n ".. Git Cloning odh-modelmesh-controller to ${TARGET_DIR} folder"
  git clone --quiet --branch $MODELMESH_CONTROLLER_BRANCH $MODELMESH_CONTROLLER_GIT odh-modelmesh-controller
else
  echo -n ".. odh-modelmesh-controller folder exist,it will reuse the existing folder"
fi
echo -e "\r ✓"

# Copy manifests templates
echo -n ".. Copying the odh-modelmesh-controller manifests to model-mesh_templates folder"
cp -R odh-modelmesh-controller/config/*  ${MODELMESH_CONTROLLER_DIR}/.
echo -e "\r ✓"

# Update files for Opendatahub
echo -n ".. Comment out ClusterServingRuntime"
sed 's+- bases/serving.kserve.io_clusterservingruntimes.yaml+# - bases/serving.kserve.io_clusterservingruntimes.yaml+g' -i ${MODELMESH_CONTROLLER_DIR}/crd/kustomization.yaml
echo -e "\r ✓"

echo -n ".. Remove builtInServerTypes"
sed '/builtInServerTypes/,$d' -i ${MODELMESH_CONTROLLER_DIR}/default/config-defaults.yaml
echo -e "\r ✓"

echo -n ".. Add parameter variable into modelmesh-controller-rolebinding"
sed 's+modelmesh-controller-rolebinding$+modelmesh-controller-rolebinding-$(mesh-namespace)+g' -i ${MODELMESH_CONTROLLER_DIR}/rbac/cluster-scope/role_binding.yaml
echo -e "\r ✓"

# Update images to adopt dynamic value using params.env
echo -n ".. Replace each image of the parameter variable 'images'"
sed 's+kserve/modelmesh$+$(odh-modelmesh)+g' -i ${MODELMESH_CONTROLLER_DIR}/default/config-defaults.yaml
sed 's+kserve/rest-proxy$+$(odh-mm-rest-proxy)+g' -i ${MODELMESH_CONTROLLER_DIR}/default/config-defaults.yaml
sed 's+kserve/modelmesh-runtime-adapter$+$(odh-modelmesh-runtime-adapter)+g' -i ${MODELMESH_CONTROLLER_DIR}/default/config-defaults.yaml
sed '/tag:/d' -i ${MODELMESH_CONTROLLER_DIR}/default/config-defaults.yaml

sed 's+modelmesh-controller:replace$+$(odh-modelmesh-controller)+g' -i ${MODELMESH_CONTROLLER_DIR}/manager/manager.yaml

sed 's+ovms-1:replace$+$(odh-openvino)+g' -i ${MODELMESH_CONTROLLER_DIR}/runtimes/ovms-1.x.yaml
echo -e "\r ✓"

echo -n ".. Replace replicas of odh modelmesh controller to 3"
yq e '.spec.replicas = 3' -i ${MODELMESH_CONTROLLER_DIR}/manager/manager.yaml
echo -e "\r ✓"

echo -n ".. Increase manager limit memory size to 2G"
yq e '.spec.template.spec.containers[0].resources.limits.memory = "2Gi"' -i  ${MODELMESH_CONTROLLER_DIR}/manager/manager.yaml
echo -e "\r ✓"

echo -n ".. Add trustAI option into config-defaults.yaml"
yq eval '."payloadProcessors" = ""'  -i ${MODELMESH_CONTROLLER_DIR}/default/config-defaults.yaml
echo -e "\r ✓"



IS_IDENTICAL=$(diff -r ${TARGET_DIR}/model-mesh_templates/odh-modelmesh-controller/ ${ODH_MANIFESTS_DIR}/model-mesh/odh-modelmesh-controller/)

if [[ z$IS_IDENTICAL == z ]]; then
  success "New Manifests are identical with previous one. You don't need to send any PR to ODH-MANIFESTS repo"
else
  info "diff -r ${TARGET_DIR}/model-mesh_templates/odh-modelmesh-controller/ ${ODH_MANIFESTS_DIR}/model-mesh/odh-modelmesh-controller/"
  echo

  die "There are some changes between new manifests and previous one. You should validate the new manifests. If it works, you need to update opendatahub/odh-manifests/model-mesh and opendatahub/odh-manifests/model-mesh_templates"
fi
