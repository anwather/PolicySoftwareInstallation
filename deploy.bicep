param storageAccountName string
param automationAccountName string
param resourceGroupName string
param location string

var modules = [
  {
    name: 'Az.Accounts'
    url: 'https://devopsgallerystorage.blob.core.windows.net/packages/az.accounts.2.2.8.nupkg'
  }
  {
    name: 'Az.Resources'
    url: 'https://devopsgallerystorage.blob.core.windows.net/packages/az.resources.3.4.0.nupkg'
  }
  {
    name: 'Az.Storage'
    url: 'https://devopsgallerystorage.blob.core.windows.net/packages/az.storage.3.6.0.nupkg'
  }
  {
    name: 'Az.Compute'
    url: 'https://devopsgallerystorage.blob.core.windows.net/packages/az.compute.4.12.0.nupkg'
  }
]

var automationVariables = [
  {
    name: 'StorageAccountName'
    value: storageAccountName
  }
  {
    name: 'ResourceGroupName'
    value: resourceGroupName
  }
]

var policyDefinitionId = '/providers/Microsoft.Authorization/policySetDefinitions/12794019-7a00-42cf-95c2-882eed337cc8'

resource st1 'Microsoft.Storage/storageAccounts@2021-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource ct1 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-01-01' = {
  name: '${storageAccountName}/default/software'
  dependsOn: [
    st1
  ]
}

resource aa 'Microsoft.Automation/automationAccounts@2020-01-13-preview' = {
  name: automationAccountName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
  }
}

resource aavars 'Microsoft.Automation/automationAccounts/variables@2020-01-13-preview' = [for j in automationVariables: {
  name: '${automationAccountName}/${j.name}'
  properties: {
    value: '"${j.value}"'
    isEncrypted: true
  }
  dependsOn: [
    aa
  ]
}]

resource perm1 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(automationAccountName)
  properties: {
    principalId: aa.identity.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    aa
  ]
}

@batchSize(1)
resource mods 'Microsoft.Automation/automationAccounts/modules@2015-10-31' = [for i in modules: {
  name: '${automationAccountName}/${i.name}'
  location: location
  properties: {
    contentLink: {
      uri: i.url
    }
  }
  dependsOn: [
    aa
  ]
}]

resource gcpol 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: guid(storageAccountName)
  location: location
  properties: {
    policyDefinitionId: policyDefinitionId
    displayName: 'Deploy Guest Configuration'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource systopic 'Microsoft.EventGrid/systemTopics@2020-10-15-preview' = {
  name: 'PolicyStateChanges'
  location: 'global'
  properties: {
    topicType: 'Microsoft.PolicyInsights.PolicyStates'
    source: subscription().id
  }
}
