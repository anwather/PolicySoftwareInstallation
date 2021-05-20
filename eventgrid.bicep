@secure()
param uri string
param topicName string
param location string

var policyDefinitionId = '/providers/Microsoft.Authorization/policyDefinitions/ebb67efd-3c46-49b0-adfe-5599eb944998'

resource softwarepol 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: guid(topicName)
  location: location
  properties: {
    policyDefinitionId: policyDefinitionId
    displayName: 'Audit windows virtual machines without PowerShell installed'
    parameters: {
      installedApplication: {
        value: 'PowerShell 7-x64'
      }
    }
  }
}

resource esub 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2020-10-15-preview' = {
  name: '${topicName}/PolicyChanges'
  properties: {
    destination: {
      endpointType: 'WebHook'
      properties: {
        endpointUrl: uri
      }
    }
    eventDeliverySchema: 'EventGridSchema'
    filter: {
      includedEventTypes: [
        'Microsoft.PolicyInsights.PolicyStateChanged'
        'Microsoft.PolicyInsights.PolicyStateCreated'
      ]
      advancedFilters: [
        {
          operatorType: 'StringContains'
          key: 'data.policyAssignmentId'
          values: [
            reference(softwarepol.name, '2020-09-01', 'full').resourceId
          ]
        }
        {
          operatorType: 'StringBeginsWith'
          key: 'data.complianceState'
          values: [
            'NonCompliant'
          ]
        }
      ]
    }
  }
}
