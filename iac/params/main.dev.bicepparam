using '../main.bicep'

param clusterName = 'aks-dev-uks-001'
param acrName = 'acrdevuks001'
param location = 'uksouth'
param fluxGitRepositoryUrl = ''
param fluxGitRepositoryPat = ''
param kvName = ''
param kvRgName = ''
param workloadIdentityName = ''
