kubectl apply -f deploy/windows-updates.yaml

# Wait for DaemonSet to be ready
kubectl get daemonset windows-updates

# Recycle daemonset pods to start updates
kubectl rollout restart daemonset windows-updates

# Check the logs from one of the pods
$podName = kubectl get pods -l app=windows-updates -o jsonpath="{.items[0].metadata.name}"
kubectl logs $podName
