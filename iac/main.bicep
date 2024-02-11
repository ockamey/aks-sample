param clusterName string
param acrName string
param location string = resourceGroup().location

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2023-11-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
    }
    dnsPrefix: '${clusterName}-dns'
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
    enableRBAC: true
    disableLocalAccounts: true
    agentPoolProfiles: [
      {
        name: 'agentpool'
        availabilityZones: [
          '1', '2', '3'
        ]
        osType: 'Linux'
        mode: 'System'
        count: 2
        vmSize: 'Standard_B2s'
        maxPods: 110
      }
    ]
  }
}

module acrRbacModule 'modules/acrRbac.bicep' = {
  name: 'acrRbacModule-${deployment().name}'
  params: {
    acrName: acr.name
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
  }
}
