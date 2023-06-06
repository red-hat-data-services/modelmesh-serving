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

ODH_MODEL_CONTROLLER_BRANCH=main
ODH_MODEL_CONTROLLER_GIT=https://github.com/opendatahub-io/odh-model-controller.git
ODH_MODEL_CONTROLLER_DIR=${TARGET_DIR}/model-mesh_templates/odh-model-controller

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

if [[ ! -d ${TARGET_DIR}/odh-model-controller ]]; then
  echo -n ".. Git Cloning odh-model-controller to ${TARGET_DIR} folder"
  git clone  --quiet --branch $ODH_MODEL_CONTROLLER_BRANCH $ODH_MODEL_CONTROLLER_GIT
else
  echo -n ".. odh-model-controller folder exist,it will reuse the existing folder"
fi
echo -e "\r ✓"

# Copy manifests templates
if [[ ! -d ${TARGET_DIR}/model-mesh_templates ]]; then
  echo -n ".. Copying the odh-model-controller manifests to model-mesh_templates folder"
  mkdir -p ${ODH_MODEL_CONTROLLER_DIR}
  cp -R odh-model-controller/config/*  ${ODH_MODEL_CONTROLLER_DIR}/.
  echo -e "\r ✓"

  echo -n ".. Copying the model-mesh_templates to ${TARGET_DIR} folder"
  cp -R $ODH_MANIFESTS_DIR/model-mesh_templates/* ${TARGET_DIR}/model-mesh_templates

else
  echo -n ".. model-mesh_template folder exist, it will reuse the existing folder"
fi
echo -e "\r ✓"

echo -n ".. Delete crd folder"
rm -rf ${ODH_MODEL_CONTROLLER_DIR}/crd
echo -e "\r ✓"

echo -n ".. Update kustomization.yaml in default folder"
if [[ $(grep external ${ODH_MODEL_CONTROLLER_DIR}/default/kustomization.yaml|wc -l) != 0 ]]; then
  sed '/external/d' -i ${ODH_MODEL_CONTROLLER_DIR}/default/kustomization.yaml
  sed '/namespace/d' -i ${ODH_MODEL_CONTROLLER_DIR}/default/kustomization.yaml
  sed '/^$/d' -i ${ODH_MODEL_CONTROLLER_DIR}/default/kustomization.yaml
fi
echo -e "\r ✓"

echo -n ".. Update kustomization.yaml in manager folder"
sed '/namespace.yaml/d' -i ${ODH_MODEL_CONTROLLER_DIR}/manager/kustomization.yaml
if [[ $(grep images ${ODH_MODEL_CONTROLLER_DIR}/manager/kustomization.yaml|wc -l) != 0 ]]; then
  sed '/images/,$d' -i ${ODH_MODEL_CONTROLLER_DIR}/manager/kustomization.yaml
  sed '$d' -i ${ODH_MODEL_CONTROLLER_DIR}/manager/kustomization.yaml
fi
echo -e "\r ✓"

if [[ -f ${ODH_MODEL_CONTROLLER_DIR}/manager/namespace.yaml ]]; then
  echo -n ".. Delete namespace.yaml file"
  rm ${ODH_MODEL_CONTROLLER_DIR}/manager/namespace.yaml
else
  echo -n ".. namespace.yaml file was already deleted"
fi
echo -e "\r ✓"

echo -n ".. Add mesh-namespace into role_binding.yaml in rbac folder"
if [[ $(grep mesh-namespace ${ODH_MODEL_CONTROLLER_DIR}/rbac/role_binding.yaml|wc -l) == 0 ]]; then
  sed '$d' -i ${ODH_MODEL_CONTROLLER_DIR}/rbac/role_binding.yaml
fi
sed 's+odh-model-controller-rolebinding$+odh-model-controller-rolebinding-$(mesh-namespace)+g' -i ${ODH_MODEL_CONTROLLER_DIR}/rbac/role_binding.yaml
echo -e "\r ✓"

IS_IDENTICAL=$(diff -r ${TARGET_DIR}/model-mesh_templates/odh-model-controller/ ${ODH_MANIFESTS_DIR}/model-mesh/odh-model-controller/)

if [[ z$IS_IDENTICAL == z ]]; then
  success "New Manifests are identical with previous one. You don't need to send any PR to ODH-MANIFESTS repo"
else
  info "diff -r ${TARGET_DIR}/model-mesh_templates/odh-model-controller/ ${ODH_MANIFESTS_DIR}/model-mesh/odh-model-controller/"
  echo

  die "There are some changes between new manifests and previous one. You should validate the new manifests. If it works, you need to update opendatahub/odh-manifests/model-mesh and opendatahub/odh-manifests/model-mesh_templates"
fi
