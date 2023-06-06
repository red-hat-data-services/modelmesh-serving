# Open Data Hub Manifests Management Guide

Opendatahub has two main manifests.
The first is the manifests used by kserve/modelmesh and the second is the manifests used by Opendatahub. Basically, the second manifest uses the first manifest, but in a modified form so that it can also be used for kfdef, and installs two components at the same time: odh-modelmesh-controller and odh-model-controller.

This document describes in detail the different ways to deploy and test the manifests used by opendatahub, as well as the workflow and commands to change the manifests when needed.

- [How to deploy manifests?](#how-to-deploy-manifests)
- [Manifests Test](#manifests-test)
- [Makefile cheatsheet](./makefile-cheatsheet.md)

## How to deploy manifests?

**Pre-requisite**

```
git clone git@github.com:Jooho/modelmesh-serving.git
cd modelmesh-serving
```

**Makefile: Upstream manifests**

This will deploy modelmesh controller, fvt components with [upstream manifests ](../../config).

```
make deploy-release-dev-mode-fvt
```

**Kustomize: odh-manifests**

This will deploy modelmesh controller with [odh-manifest manifests](../odh-manifests/modelmesh) using kustomize cli

```
kustomize build opendatahub/odh-manifests/model-mesh/base  | oc create -f -
```

**Kfctl: odh-manifests(kfdef)**

This will deploy modelmesh controller with [kfdef](../kfdef.yaml) file using kfcfl cli

```
kfctl build -V -f ./opendatahub/kfdef/kfdef.yaml   -d | oc create -f -
```

**opendatahub operator: odh-manifest(kfdef)**

This will deploy modelmesh controller with [kfdef](./kfdef.yaml) file using kfcfl cli

```
oc create -f opendatahub/scripts/manifests/subs_odh_operator.yaml

 # There are 3 options (kfdef.yaml/kfdef-fast.yaml/kfdef-stable.yaml)
oc create -f ./opendatahub/kfdef/kfdef.yaml
```

## How to test manifests?

Manifests are divided into two main categories: upstream manifests and opendatahub manifests.

There are three ways to test the opendatahub manifests, and if the opendatahub manifests are changed, you need to validate the opendatahub manifests by proceeding with these three methods in turn.

First, you need to deploy the modelmesh using kustomize. In this case, you don't need to deploy the opendatahub operator and also you don't need to use kfdef, so you can quickly and easily validate the manifests.

Next, check if the validated manifests can be deployed via kfcfl in kfdef format.
This folder has [kfdef-local.yaml](../kfdef/kfdef-local.yaml) file that use a /tmp/odh-manifests.gzip file on local. So you don't need to push this change into any remote github repository.

Finally, we validate the manifest by actually generating the corresponding [kfdef.yaml](../kfdef/kfdef.yaml) manifest through the opendatahub operator.

**Pre-requisite**

- Create a OpenShift Cluster (OSD prefered)
- Login to the cluster
- Execute the following commands
  ```
  export OCP_TOKEN=$(oc whoami --show-token)
  export OCP_ADDRESS=$(oc whoami --show-server|cut -d/ -f3)
  export ctrlnamespace=opendatahub
  ```

### Upstream Manifests

**Deploy ModelMesh Controller and start FVT Test**

```
NAMESPACE=modelmesh-serving make e2e-test
```

**Clean up**

```
NAMESPACE=modelmesh-serving make e2e-delete
```

### odh-manifests with kustomize

**Deploy ModelMesh Controller**

```
cd opendatahub/odh-manifests/model-mesh/base; kustomize edit set namespace ${ctrlnamespace} ; cd -
kustomize build opendatahub/odh-manifests/model-mesh/base  | oc create -f -

oc project ${ctrlnamespace}
```

**Deploy required components for fvt test(minio/pvc)**

```
NAMESPACE=modelmesh-serving make deploy-fvt-for-odh
```

**Start FVT Test**

```
CONTROLLERNAMESPACE=opendatahub NAMESPACE=modelmesh-serving NAMESPACESCOPEMODE=true make fvt
```

**Clean Up**

```
C_MM_TEST=true C_MM_CTRL_KUSTOMIZE=true make cleanup-for-odh
```

### Local odh-manifests with kfctl

**GZip Manifests for test**

For local test, you should archive opendatahub manifests folder.

```
 # Try this in parent folder of the modelmesh-serving folder

tar czvf /tmp/odh-manifests.gzip modelmesh-serving/opendatahub/odh-manifests/
```

**Deploy ModelMesh Controller**

```
cd modelmesh-serving
oc new-project opendatahub

rm /tmp/modelmesh-e2e -rf
sed "s/%controller-namespace%/${ctrlnamespace}/g" opendatahub/kfdef/kfdef-local.yaml  > /tmp/modelmesh-e2e/kfdef.yaml

kfctl build -V -f /tmp/modelmesh-e2e/kfdef.yaml -d | oc create -f -
```

**Deploy required components for fvt test(minio/pvc)**

```
NAMESPACE=modelmesh-serving make deploy-fvt-for-odh
```

**Start FVT Test**

```
CONTROLLERNAMESPACE=opendatahub NAMESPACE=modelmesh-serving NAMESPACESCOPEMODE=true make fvt
```

**Clean Up**

```
C_MM_TEST=true C_MM_CTRL_KFCTL=true make cleanup-for-odh
```

If FVT test failed, retry 1~2 times more.
After it passes fvt test, you need to send all changes to your repo.

### Remote odh-manifests with opendatahub operator

**Export environmental variabels**

```
 # this will be used for repos.uri
 # (ex)      uri: https://api.github.com/repos/%mm_user%/modelmesh-serving/tarball/%mm_branch%
 #           uri: https://api.github.com/repos/Jooho/modelmesh-serving/tarball/restructed_odh_manifests
export mm_user=Jooho
export mm_branch=restructed_odh_manifests
```

**Deploy ModelMesh Controller**

```
oc create -f opendatahub/scripts/manifests/subs_odh_operator.yaml

oc project opendatahub || oc new-project opendatahub

 # There are 3 options (kfdef.yaml/kfdef-fast.yaml/kfdef-stable.yaml)
sed "s/%mm_user%/${mm_user}/g" opendatahub/kfdef/kfdef.yaml | sed "s/%mm_branch%/${mm_branch}/g" |oc create -n opendatahub -f -

 # fast (main branch)
 # sed "s/%mm_user%/${mm_user}/g" opendatahub/kfdef/kfdef-stable.yaml | sed "s/%mm_branch%/${mm_branch}/g" | oc create -n opendatahub -f  opendatahub/kfdef/kfdef-fast.yaml

 # stable (release branch)
 # sed "s/%mm_user%/${mm_user}/g" opendatahub/kfdef/kfdef-stable.yaml| sed "s/%mm_branch%/${mm_branch}/g" | oc create -n opendatahub -f
```

**Deploy required components for fvt test(minio/pvc)**

```
NAMESPACE=modelmesh-serving make deploy-fvt-for-odh

 # fast or stable
 # TAG=fast NAMESPACE=modelmesh-serving make deploy-fvt-for-odh
 # TAG=stable NAMESPACE=modelmesh-serving make deploy-fvt-for-odh
```

**Start FVT Test**

```
CONTROLLERNAMESPACE=opendatahub NAMESPACE=modelmesh-serving NAMESPACESCOPEMODE=true make fvt
```

If all 3 manifests validations passes, you can compare this manifests with odh-manifest one. Then you can send a PR to the changes.

**Clean Up**

```
C_MM_TEST=true C_MM_CTRL_OPS=true make cleanup-for-odh
```

### E2E Test with odh manifests

This is all-in-one script that includes deploying modelmesh controller, fvt related objects and doing fvt test.

```
CONTROLLERNAMESPACE=opendatahub NAMESPACE=modelmesh-serving NAMESPACESCOPEMODE=true make e2e-test-for-odh
```

## Clean Up All Test Objects

If you finish all tests, you can delete all objects related this test.

```
C_FULL=true make cleanup-for-odh
```
