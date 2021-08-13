#!/bin/bash
set -e

importNames="$(kubectl get -n hpecp hpecpconfig hpecp-global-config -o=jsonpath="{.spec.tenantServiceImports[*].importName}")"
if grep -q 'kf-dashboard' <<< "$importNames"; then
  echo "Patch not needed"
else
  kubectl patch -n hpecp hpecpconfig hpecp-global-config --type json -p '
  [
    {
      "op": "add",
      "path": "/spec/tenantServiceImports/-",
      "value": {
        "category": "default",
        "importName": "kf-dashboard",
        "targetName": "istio-ingressgateway",
        "targetNamespace": "istio-system",
        "targetPorts": [
          {
            "importName": "http-80",
            "targetName": "http-80"
          }
        ]
      }
    }
  ]
  '
  echo "Patch applied"
fi
