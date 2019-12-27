#!/bin/bash

# read - https://github.com/rancher/k3s/issues/117
# and also - https://cert-manager.io/docs/installation/kubernetes/
######

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Create service account and RBAC resources for tiller
kubectl apply -f https://raw.githubusercontent.com/gdha/k3s-intro/master/deploy/manifests/tiller-serviceaccount-rbac.yaml

# Initialize tiller
helm init --service-account tiller --wait

# Install the CustomResourceDefinition resources separately
kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml

# Create the namespace for cert-manager
kubectl create namespace cert-manager

# Label the cert-manager namespace to disable resource validation
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
helm install \
  --name cert-manager \
  --namespace cert-manager \
  --version v0.12.0 \
  jetstack/cert-manager

# Wait for the pods to be ready here...
kubectl -n cert-manager rollout status deployment/cert-manager
kubectl -n cert-manager rollout status deployment/cert-manager-cainjector
kubectl -n cert-manager rollout status deployment/cert-manager-webhook

# Create certificates, Issuer and ClusterIssuer to test deployment
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager-test
---
apiVersion: certmanager.k8s.io/v1alpha1
kind: Issuer
metadata:
  name: test-selfsigned
  namespace: cert-manager-test
spec:
  selfSigned: {}
---
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: selfsigned-cert
  namespace: cert-manager-test
spec:
  commonName: example.com
  secretName: selfsigned-cert-tls
  issuerRef:
    name: test-selfsigned
---
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: test-selfsigned-cluster
spec:
  selfSigned: {}
---
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: selfsigned-cert-cluster
  namespace: cert-manager-test
spec:
  commonName: example.com
  secretName: selfsigned-cert-tls-cluster
  issuerRef:
    name: test-selfsigned-cluster
    kind: ClusterIssuer
EOF

# Check that certs are issued
kubectl describe certificate -n cert-manager-test
