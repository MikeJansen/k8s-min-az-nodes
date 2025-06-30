#!/usr/bin/env bash

# We need minikube running
minikube start --nodes=3 --driver=docker

# Add zone labels so the zone affinity works
kubectl label node minikube topology.kubernetes.io/zone=az1
kubectl label node minikube-m02 topology.kubernetes.io/zone=az2
kubectl label node minikube-m03 topology.kubernetes.io/zone=az3

# Build the app image and load it into minikube
docker build -t idle:latest .
minikube image load idle:latest

# Install the application
helm install min-nodes ./helm --set image.pullPolicy=IfNotPresent --set replicaCount=3

# Make sure it comes up as expecgted within 30 seconds
kubectl wait --for=condition=available --timeout=30s deployment/min-nodes

# Cleanup
minikube delete
