param clusterName string
param acrName string
param location string = resourceGroup().location
param fluxGitRepositoryUrl string
@secure()
param fluxGitRepositoryPat string

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2023-08-02-preview' = {
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
    ingressProfile: {
      webAppRouting: {
        enabled: true
      }
    }
  }
}

resource flux 'Microsoft.KubernetesConfiguration/extensions@2023-05-01' = {
  name: 'flux'
  scope: aks
  properties: {
    extensionType: 'microsoft.flux'
    scope: {
      cluster: {
        releaseNamespace: 'flux-system'
      }
    }
  }
}

resource fluxConfig 'Microsoft.KubernetesConfiguration/fluxConfigurations@2023-05-01' = {
  name: 'aks-flux-config'
  scope: aks
  properties: {
    scope: 'cluster'
    namespace: 'cluster-config'
    sourceKind: 'GitRepository'
    gitRepository: {
      url: fluxGitRepositoryUrl
      repositoryRef: {
        branch: 'main'
      }
      httpsUser: 'not-relevant-since-PAT-is-used'
    }
    configurationProtectedSettings: {
      httpsKey: base64(fluxGitRepositoryPat) 
    }
    kustomizations: {
      apps: {
        path: './kustomize/dev'
        prune: true
      }
    }
  }
}

module acrPullRoleAssignmentModule 'modules/acrRbac.bicep' = {
  name: 'acrPullRoleAssignmentModule-${deployment().name}'
  params: {
    acrName: acr.name
    roleId: '7f951dda-4ed3-4680-a7ca-43fe172d538d' //AcrPull
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

module aksRbacClusterAdminRoleAssignmentModule 'modules/aksRbac.bicep' = {
  name: 'aksRbacClusterAdminRoleAssignmentModule-${deployment().name}'
  params: {
    aksName: aks.name
    roleId: 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b' // Azure Kubernetes Service RBAC Cluster Admin
    principalId: '0a97ce96-3a13-4d64-86aa-cbb0f5c014ab' // AKS Admin Group Object Id
    principalType: 'Group'
  }
}
