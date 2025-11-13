# All the variables for the deployment
$subscriptionName = "workload1-production-online"
$aadAdminGroupContains = "janneops"

$aksName = "myakswin"
$acrName = "myacrwin0000010"
$workspaceName = "mywinworkspace"
$vnetName = "mywin-vnet"
$subnetAks = "AksSubnet"
$nsgAks = "nsg-AksSubnet"
$clusterIdentityName = "myakswin-cluster"
$kubeletIdentityName = "myakswin-kubelet"
$resourceGroupName = "rg-myakswin"
$location = "swedencentral"

# Login and set correct context
az login -o table
az account set --subscription $subscriptionName -o table

$resourcegroupid = (az group create -l $location -n $resourceGroupName -o table --query id -o tsv)

# Prepare extensions and providers
az extension add --upgrade --yes --name aks-preview

# Enable features
# az feature register --namespace "Microsoft.ContainerService" --name "EnablePodIdentityPreview"
# az feature register --namespace "Microsoft.ContainerService" --name "AKS-ScaleDownModePreview"
# az feature register --namespace "Microsoft.ContainerService" --name "PodSubnetPreview"
# az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/EnablePodIdentityPreview')].{Name:name,State:properties.state}"
# az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AKS-ScaleDownModePreview')].{Name:name,State:properties.state}"
# az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/PodSubnetPreview')].{Name:name,State:properties.state}"
# az provider register --namespace Microsoft.ContainerService

# Remove extension in case conflicting previews
# az extension remove --name aks-preview

$acrid = (az acr create -l $location -g $resourceGroupName -n $acrName --sku Basic --query id -o tsv)
$acrid

$aadAdmingGroup = (az ad group list --display-name $aadAdminGroupContains --query [].id -o tsv)
$aadAdmingGroup

$workspaceid = (az monitor log-analytics workspace create -g $resourceGroupName -n $workspaceName --query id -o tsv)
$workspaceid

$vnetid = (az network vnet create -g $resourceGroupName --name $vnetName `
    --address-prefix 10.0.0.0/8 `
    --query newVNet.id -o tsv)
$vnetid

$subnetaksid = (az network vnet subnet create -g $resourceGroupName --vnet-name $vnetName `
    --name $subnetAks --address-prefixes 10.2.0.0/20 `
    --query id -o tsv)
$subnetaksid

$clusterIdentityId = (az identity create --name $clusterIdentityName --resource-group $resourceGroupName --query id -o tsv)
$clusterIdentityId

$kubeletIdentityId = (az identity create --name $kubeletIdentityName --resource-group $resourceGroupName --query id -o tsv)
$kubeletIdentityId

az aks get-versions -l $location -o table

# Note: for public cluster you need to authorize your ip to use api
$myip = (curl --no-progress-meter https://myip.jannemattila.com)
$myip

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
  --kubernetes-version 1.33.5 `
  --enable-addons monitoring `
  --enable-aad `
  --enable-managed-identity `
  --disable-local-accounts `
  --no-ssh-key `
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
  --node-count 1 --enable-cluster-autoscaler --min-count 1 --max-count 3 `
  --node-osdisk-type "Ephemeral" `
  --node-vm-size "Standard_D8ds_v4" `
  --os-type Windows `
  --max-pods 150

# #######################
#     _    ____ ____
#    / \  / ___|  _ \
#   / _ \| |   | |_) |
#  / ___ \ |___|  _ <
# /_/   \_\____|_| \_\
# Build
# #######################
#region ACR Build

$imageTag = Get-Date -Format "yyyyMMddHHmmss"
az acr build --registry $acrName --platform windows --image "win-helloworld:$imageTag" .\src\helloworld\

az acr build --registry $acrName --platform windows --image "win-webapp:$imageTag" .\src\aspnet\

az acr build --registry $acrName --platform windows --image "win-webapp-network-tester:$imageTag" .\src\webapp-network-tester\

# Size of "win-helloworld:
$sizeInBytes1 = (az acr manifest list-metadata -r $acrName -n "win-helloworld" --query '[].{Size: imageSize, Tags: tags}' | jq ".[0].Size")
$sizeInGB1 = [math]::Round($sizeInBytes1 / 1GB, 2)
$sizeInGB1

# Size of "win-webapp:
$sizeInBytes2 = (az acr manifest list-metadata -r $acrName -n "win-webapp" --query '[].{Size: imageSize, Tags: tags}' | jq ".[0].Size")
$sizeInGB2 = [math]::Round($sizeInBytes2 / 1GB, 2)
$sizeInGB2

# From: https://github.com/Azure/acr/issues/169
$repositories = (az acr repository list -n $acrName -o tsv)
$repositories

az acr repository list -n $acrName -o json
foreach ($repo in $repositories) {
  "Repository: $repo"
  az acr manifest list-metadata -r $acrName -n $repo --query '[].{Name: name, Size: imageSize, Tags: tags[0],Created: createdTime, Architecture: architecture, OS: os}' -o table
}

#endregion

##########################
#  _   _ ____   ____
# | \ | / ___| / ___|
# |  \| \___ \| |  _
# | |\  |___) | |_| |
# |_| \_|____/ \____|
# Network Security Group
##########################
#region NSG

az network nsg create -n $nsgAks -g $resourceGroupName
az network vnet subnet update -g $resourceGroupName --vnet-name $vnetName --name $subnetAks --network-security-group $nsgAks

$myip
az network nsg rule create `
  -g $resourceGroupName `
  --nsg-name $nsgAks `
  -n "allow-myip" --priority 1000 `
  --source-address-prefixes "$myip/32" `
  --destination-address-prefixes "*" `
  --destination-port-ranges '80' `
  --access Allow `
  --description "Allow access to port 80 for myip"

#endregion

# ##################################
#  ____             _
# |  _ \  ___ _ __ | | ___  _   _
# | | | |/ _ \ '_ \| |/ _ \| | | |
# | |_| |  __/ |_) | | (_) | |_| |
# |____/ \___| .__/|_|\___/ \__, |
#            |_|            |___/
# Windows and Linux workloads
# ##################################
az aks install-cli

az aks get-credentials -n $aksName -g $resourceGroupName --overwrite-existing
kubelogin convert-kubeconfig -l azurecli

kubectl get nodes -o wide
kubectl get nodes -L agentpool
kubectl get nodes -o custom-columns="NAME:.metadata.name, OS:.status.nodeInfo.operatingSystem, IMAGE:.status.nodeInfo.osImage, RUNTIME:.status.nodeInfo.containerRuntimeVersion"
kubectl get nodes -o yaml

# Deploy all items from demo namespace
kubectl apply -f deploy/demo/namespace.yaml
kubectl apply -f deploy/demo/service.yaml
kubectl apply -f deploy/demo/deployment.yaml

kubectl get deployment -n demo
kubectl describe deployment -n demo
kubectl get pod -n demo
kubectl describe pod -n demo
kubectl get svc -n demo

$demo_ip = (kubectl get service -n demo -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")
$demo_ip

kubectl get pod -n demo
$demo_pod = (kubectl get pod -n demo -o name | Select-Object -First 1)
$demo_pod

####
# Connect to using "cmd.exe":
kubectl exec --stdin --tty $demo_pod -n demo -- cmd

# Exit container
exit
####

# Deploy all items from helloworld namespace
kubectl apply -f deploy/helloworld/namespace.yaml
Get-Content deploy/helloworld/deployment.yaml | `
  ForEach-Object { $_ -Replace "__acrName__", $acrName } | `
  ForEach-Object { $_ -Replace "__imageTag__", $imageTag } | `
  kubectl apply -f -
kubectl apply -f deploy/helloworld/service.yaml

kubectl get deployment -n helloworld
kubectl describe deployment -n helloworld

kubectl get pod -n helloworld
$helloworld_pod = (kubectl get pod -n helloworld -o name | Select-Object -First 1)
$helloworld_pod

####
# Connect to using "cmd.exe":
kubectl exec --stdin --tty $helloworld_pod -n helloworld -- cmd

# Exit container
exit
####

kubectl describe $helloworld_pod -n helloworld
kubectl get service -n helloworld

$helloworld_ip = (kubectl get service -n helloworld -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")
$helloworld_ip

curl $helloworld_ip
# -> <html>...Hello World from Windows Container running in AKS...</html>

# Deploy all items from aspnet namespace
kubectl apply -f deploy/aspnet/namespace.yaml
Get-Content deploy/aspnet/deployment.yaml | `
  ForEach-Object { $_ -Replace "__acrName__", $acrName } | `
  ForEach-Object { $_ -Replace "__imageTag__", $imageTag } | `
  kubectl apply -f -
kubectl apply -f deploy/aspnet/service.yaml

kubectl get deployment -n aspnet
kubectl describe deployment -n aspnet

kubectl get pod -n aspnet
$aspnet_pod = (kubectl get pod -n aspnet -o name | Select-Object -First 1)
$aspnet_pod

kubectl describe $aspnet_pod -n aspnet
kubectl get service -n aspnet

$aspnet_ip = (kubectl get service -n aspnet -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")
$aspnet_ip

curl $aspnet_ip

# Deploy all items from webapp-network-tester namespace
kubectl apply -f deploy/webapp-network-tester/namespace.yaml
Get-Content deploy/webapp-network-tester/deployment.yaml | `
  ForEach-Object { $_ -Replace "__acrName__", $acrName } | `
  ForEach-Object { $_ -Replace "__imageTag__", $imageTag } | `
  kubectl apply -f -
kubectl apply -f deploy/webapp-network-tester/service.yaml

kubectl get deployment -n webapp-network-tester
kubectl describe deployment -n webapp-network-tester

kubectl get pod -n webapp-network-tester
kubectl describe pod -n webapp-network-tester

$webapp_network_tester_pod = (kubectl get pod -n webapp-network-tester -o name | Select-Object -First 1)
$webapp_network_tester_pod

kubectl describe $webapp_network_tester_pod -n webapp-network-tester
kubectl get service -n webapp-network-tester

$webapp_network_tester_ip = (kubectl get service -n webapp-network-tester -o jsonpath="{.items[0].status.loadBalancer.ingress[0].ip}")
$webapp_network_tester_ip

curl $webapp_network_tester_ip

####
# Connect to using "cmd.exe":
kubectl exec --stdin --tty $webapp_network_tester_pod -n helloworld -- cmd

# Exit container
exit
####

# Wipe out the resources
az group delete --name $resourceGroupName -y
