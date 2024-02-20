param aksName string
param principalId string
param roleId string
param principalType string

resource aks 'Microsoft.ContainerService/managedClusters@2023-08-02-preview' existing = {
  name: aksName
}

resource aksRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aks.name, principalId, roleId)
  scope: aks
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleId)
  }
}
