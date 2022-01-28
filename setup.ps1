# All the variables for the deployment
$subscriptionName = "AzureDev"
$aadAdminGroupContains = "janne''s"

$aksName = "myakswin"
$acrName = "myacrwin0000010"
$workspaceName = "mywinworkspace"
$vnetName = "mywin-vnet"
$subnetAks = "AksSubnet"
$identityName = "myakswin"
$resourceGroupName = "rg-myakswin"
$location = "westeurope"

# Login and set correct context
az login -o table
az account set --subscription $subscriptionName -o table

$subscriptionID = (az account show -o tsv --query id)
$resourcegroupid = (az group create -l $location -n $resourceGroupName -o table --query id -o tsv)
echo $resourcegroupid

# Prepare extensions and providers
az extension add --upgrade --yes --name aks-preview

# Enable features
az feature register --namespace "Microsoft.ContainerService" --name "EnablePodIdentityPreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-ScaleDownModePreview"
az feature register --namespace "Microsoft.ContainerService" --name "PodSubnetPreview"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/EnablePodIdentityPreview')].{Name:name,State:properties.state}"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AKS-ScaleDownModePreview')].{Name:name,State:properties.state}"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/PodSubnetPreview')].{Name:name,State:properties.state}"
az provider register --namespace Microsoft.ContainerService

# Remove extension in case conflicting previews
# az extension remove --name aks-preview

$acrid = (az acr create -l $location -g $resourceGroupName -n $acrName --sku Basic --query id -o tsv)
echo $acrid

$aadAdmingGroup = (az ad group list --display-name $aadAdminGroupContains --query [].objectId -o tsv)
echo $aadAdmingGroup

$workspaceid = (az monitor log-analytics workspace create -g $resourceGroupName -n $workspaceName --query id -o tsv)
echo $workspaceid

$vnetid = (az network vnet create -g $resourceGroupName --name $vnetName `
    --address-prefix 10.0.0.0/8 `
    --query newVNet.id -o tsv)
echo $vnetid

$subnetaksid = (az network vnet subnet create -g $resourceGroupName --vnet-name $vnetName `
    --name $subnetAks --address-prefixes 10.2.0.0/20 `
    --query id -o tsv)
echo $subnetaksid

$identityid = (az identity create --name $identityName --resource-group $resourceGroupName --query id -o tsv)
echo $identityid

az aks get-versions -l $location -o table

# Note: for public cluster you need to authorize your ip to use api
$myip = (curl --no-progress-meter https://api.ipify.org)
echo $myip

# Note about private clusters:
# https://docs.microsoft.com/en-us/azure/aks/private-clusters

# For private cluster add these:
#  --enable-private-cluster
#  --private-dns-zone None

az aks create -g $resourceGroupName -n $aksName `
  --max-pods 50 --network-plugin azure `
  --node-count 1 --enable-cluster-autoscaler --min-count 1 --max-count 2 `
  --node-osdisk-type "Ephemeral" `
  --node-vm-size "Standard_D8ds_v4" `
  --kubernetes-version 1.22.4 `
  --enable-addons monitoring `
  --enable-aad `
  --enable-managed-identity `
  --disable-local-accounts `
  --aad-admin-group-object-ids $aadAdmingGroup `
  --workspace-resource-id $workspaceid `
  --attach-acr $acrid `
  --load-balancer-sku standard `
  --vnet-subnet-id $subnetaksid `
  --assign-identity $identityid `
  --api-server-authorized-ip-ranges $myip `
  -o table

# Create secondary node pool for Windows workloads
$nodepool2 = "winos"
az aks nodepool add -g $resourceGroupName --cluster-name $aksName `
  --name $nodepool2 `
  --node-count 1 --enable-cluster-autoscaler --min-count 1 --max-count 2 `
  --node-osdisk-type "Ephemeral" `
  --node-vm-size "Standard_D8ds_v4" `
  --os-type Windows `
  --aks-custom-headers WindowsContainerRuntime=containerd `
  --max-pods 150

sudo az aks install-cli

az aks get-credentials -n $aksName -g $resourceGroupName --overwrite-existing

kubectl get nodes -o wide
kubectl get nodes -L agentpool
kubectl get nodes -o custom-columns="NAME:.metadata.name, OS:.status.nodeInfo.operatingSystem, IMAGE:.status.nodeInfo.osImage, RUNTIME:.status.nodeInfo.containerRuntimeVersion"
kubectl get nodes -o yaml

############################################
#  _   _      _                      _
# | \ | | ___| |___      _____  _ __| | __
# |  \| |/ _ \ __\ \ /\ / / _ \| '__| |/ /
# | |\  |  __/ |_ \ V  V / (_) | |  |   <
# |_| \_|\___|\__| \_/\_/ \___/|_|  |_|\_\
# Tester web app demo
############################################

# Deploy all items from helloworld namespace
kubectl apply -f deploy/helloworld/namespace.yaml
kubectl apply -f deploy/helloworld/deployment.yaml
kubectl apply -f deploy/helloworld/service.yaml

kubectl get deployment -n helloworld
kubectl describe deployment -n helloworld

kubectl get pod -n helloworld
$pod1 = (kubectl get pod -n helloworld -o name | head -n 1)
echo $pod1

kubectl describe $pod1 -n demos
kubectl get service -n helloworld

$ingressip = (kubectl get service -n demos -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")
echo $ingressip

curl $ingressip
# -> <html><body>Hello there!</body></html>

kubectl apply -f deploy/aspnet/namespace.yaml
kubectl apply -f deploy/aspnet/deployment.yaml
kubectl apply -f deploy/aspnet/service.yaml

kubectl get pod -n aspnet
kubectl get service -n aspnet

# ##########################################################
#     _         _                        _   _
#    / \  _   _| |_ ___  _ __ ___   __ _| |_(_) ___  _ __
#   / _ \| | | | __/ _ \| '_ ` _ \ / _` | __| |/ _ \| '_ \
#  / ___ \ |_| | || (_) | | | | | | (_| | |_| | (_) | | | |
# /_/   \_\__,_|\__\___/|_| |_| |_|\__,_|\__|_|\___/|_| |_|
# Azure CLI automation demo
# ##########################################################

az acr build --registry $acrName --platform windows --image "win-helloworld:v1" .\src\helloworld\
az acr build --registry $acrName --platform windows --image "win-webapp:v1" .\src\aspnet\

$sizeInBytes = (az acr repository show-manifests -n $acrName --repository win-helloworld --detail --query '[].{Size: imageSize, Tags: tags}' | jq ".[0].Size")
$sizeInGB = [math]::Round($sizeInBytes / 1GB, 2)

# From: https://github.com/Azure/acr/issues/169
$repositories = (az acr repository list -n $acrName -o tsv)
$repositories

foreach ($repo in $repositories) {
  az acr repository show-manifests -n $acrName --repository $repo --detail --query '[].{Size: imageSize, Tags: tags[0],Created: createdTime, Architecture: architecture, OS: os}' -o tsv
}

cat <<EOF > az-automation.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
name: az-automation
namespace: az-automation
spec:
replicas: 1
selector:
matchLabels:
app: az-automation
template:
metadata:
labels:
app: az-automation
spec:
containers:
- image: $acrName.azurecr.io/az-cli-automation-demo:v1
name: az-automation
EOF
cat az-automation.yaml

kubectl apply -f az-automation.yaml

kubectl get deployment -n az-automation
kubectl describe deployment -n az-automation

automationpod1=$(kubectl get pod -n az-automation -o name | head -n 1)
echo $automationpod1
kubectl logs $automationpod1 -n az-automation
kubectl exec --stdin --tty $automationpod1 -n az-automation -- /bin/sh

# You can test this even yourself
az login --identity -o table
az group list -o table

# Exit container
exit

# Wipe out the resources
az group delete --name $resourceGroupName -y
