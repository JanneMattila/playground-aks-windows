# All the variables for the deployment
$subscriptionName = "AzureDev"
$aadAdminGroupContains = "janne''s"

$aksName = "myakswin"
$acrName = "myacrwin0000010"
$workspaceName = "mywinworkspace"
$vnetName = "mywin-vnet"
$subnetAks = "AksSubnet"
$clusterIdentityName = "myakswin-cluster"
$kubeletIdentityName = "myakswin-kubelet"
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

$aadAdmingGroup = (az ad group list --display-name $aadAdminGroupContains --query [].id -o tsv)
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

$clusterIdentityId = (az identity create --name $clusterIdentityName --resource-group $resourceGroupName --query id -o tsv)
echo $clusterIdentityId

$kubeletIdentityId = (az identity create --name $kubeletIdentityName --resource-group $resourceGroupName --query id -o tsv)
echo $kubeletIdentityId

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
  --assign-identity $clusterIdentityId `
  --assign-kubelet-identity $kubeletIdentityId `
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

# #######################
#     _    ____ ____
#    / \  / ___|  _ \
#   / _ \| |   | |_) |
#  / ___ \ |___|  _ <
# /_/   \_\____|_| \_\
# Build
# #######################

az acr build --registry $acrName --platform windows --image "win-helloworld:v1" .\src\helloworld\
az acr build --registry $acrName --platform windows --image "win-webapp:v1" .\src\aspnet\

# Size of "win-helloworld:
$sizeInBytes1 = (az acr repository show-manifests -n $acrName --repository "win-helloworld" --detail --query '[].{Size: imageSize, Tags: tags}' | jq ".[0].Size")
$sizeInGB1 = [math]::Round($sizeInBytes1 / 1GB, 2)

# Size of "win-webapp:
$sizeInBytes2 = (az acr repository show-manifests -n $acrName --repository "win-webapp" --detail --query '[].{Size: imageSize, Tags: tags}' | jq ".[0].Size")
$sizeInGB2 = [math]::Round($sizeInBytes2 / 1GB, 2)

# From: https://github.com/Azure/acr/issues/169
$repositories = (az acr repository list -n $acrName -o tsv)
$repositories

az acr repository list -n $acrName -o json
foreach ($repo in $repositories) {
  "Repository: $repo"
  az acr repository show-manifests -n $acrName --repository $repo --detail --query '[].{Name: name, Size: imageSize, Tags: tags[0],Created: createdTime, Architecture: architecture, OS: os}' -o table
}

# ##################################
#  ____             _
# |  _ \  ___ _ __ | | ___  _   _
# | | | |/ _ \ '_ \| |/ _ \| | | |
# | |_| |  __/ |_) | | (_) | |_| |
# |____/ \___| .__/|_|\___/ \__, |
#            |_|            |___/
# Windows and Linux workloads
# ##################################
sudo az aks install-cli

az aks get-credentials -n $aksName -g $resourceGroupName --overwrite-existing

kubectl get nodes -o wide
kubectl get nodes -L agentpool
kubectl get nodes -o custom-columns="NAME:.metadata.name, OS:.status.nodeInfo.operatingSystem, IMAGE:.status.nodeInfo.osImage, RUNTIME:.status.nodeInfo.containerRuntimeVersion"
kubectl get nodes -o yaml

# Deploy all items from helloworld namespace
kubectl apply -f deploy/helloworld/namespace.yaml
Get-Content deploy/helloworld/deployment.yaml | `
  ForEach-Object { $_ -Replace "__acrName__", $acrName } | `
  ForEach-Object { $_ -Replace "__imageTag__", "v1" } | `
  kubectl apply -f -
kubectl apply -f deploy/helloworld/service.yaml

kubectl get deployment -n helloworld
kubectl describe deployment -n helloworld

kubectl get pod -n helloworld
$helloworld_pod = (kubectl get pod -n helloworld -o name | Select-Object -First 1)
echo $helloworld_pod

####
# Connect to using "cmd.exe":
kubectl exec --stdin --tty $helloworld_pod -n helloworld -- cmd

# Exit container
exit
####

kubectl describe $helloworld_pod -n helloworld
kubectl get service -n helloworld

$helloworld_ip = (kubectl get service -n helloworld -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")
echo $helloworld_ip

curl $helloworld_ip
# -> <html>...Hello World from Windows Container running in AKS...</html>

# Deploy all items from aspnet namespace
kubectl apply -f deploy/aspnet/namespace.yaml
Get-Content deploy/aspnet/deployment.yaml | `
  ForEach-Object { $_ -Replace "__acrName__", $acrName } | `
  ForEach-Object { $_ -Replace "__imageTag__", "v1" } | `
  kubectl apply -f -
kubectl apply -f deploy/aspnet/service.yaml

kubectl get deployment -n aspnet
kubectl describe deployment -n aspnet

kubectl get pod -n aspnet
$aspnet_pod = (kubectl get pod -n aspnet -o name | Select-Object -First 1)
echo $aspnet_pod

kubectl describe $aspnet_pod -n aspnet
kubectl get service -n aspnet

$aspnet_ip = (kubectl get service -n aspnet -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")
echo $aspnet_ip

curl $aspnet_ip

# Wipe out the resources
az group delete --name $resourceGroupName -y
