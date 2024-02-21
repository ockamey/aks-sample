param dnsName string
param principalId string
param roleId string
param principalType string

resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: dnsName
}

resource dnsZoneRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, dnsZone.name, principalId, roleId)
  scope: dnsZone
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleId)
  }
}
