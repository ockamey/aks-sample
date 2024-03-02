param clusterName string
param acrName string
param location string = resourceGroup().location
param fluxGitRepositoryUrl string
@secure()
param fluxGitRepositoryPat string
param kvName string
param kvRgName string
param workloadIdentityName string

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
}

resource workloadIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: workloadIdentityName
  location: location
}

resource aks 'Microsoft.ContainerService/managedClusters@2023-08-02-preview' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: '1.28'
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
    }
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
    }
    dnsPrefix: '${clusterName}-dns'
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: true
      }
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: true
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
        dnsZoneResourceIds: [
          myapiDnsZone.id
        ]
      }
    }
  }
}

resource winNodePool 'Microsoft.ContainerService/managedClusters/agentPools@2023-11-01' = {
  name: 'win'
  parent: aks
  properties: {
    availabilityZones: [
      '1', '2', '3'
    ]
    osType: 'Windows'
    osSKU: 'Windows2019'
    mode: 'User'
    count: 1
    vmSize: 'Standard_B2ms'
    maxPods: 110
  }
}

resource myapiDnsZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: 'myapi.com'
  location: 'global'
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
      syncIntervalInSeconds: 180
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

module kvRouteAddOnRbacKvSecretsUserRoleAssignmentModule 'modules/kvRbac.bicep' = {
  name: 'kvRouteAddOnRbacKvSecretsUserRoleAssignmentModule-${deployment().name}'
  scope: resourceGroup(kvRgName)
  params: {
    kvName: kvName
    principalId: aks.properties.ingressProfile.webAppRouting.identity.objectId
    principalType: 'ServicePrincipal'
    roleId: '4633458b-17de-408a-b874-0445c86b69e6' //Key Vault Secrets User
  }
}

module myApiDnsZoneContributorRoleAssignmentModule 'modules/dnsRbac.bicep' = {
  name: 'myApiDnsZoneContributorRoleAssignmentModule-${deployment().name}'
  params: {
    dnsName: myapiDnsZone.name
    principalId: aks.properties.ingressProfile.webAppRouting.identity.objectId
    principalType: 'ServicePrincipal'
    roleId: 'befefa01-2a29-4197-83a8-272ff33ce314' //DNS Zone Contributor
  }
}
