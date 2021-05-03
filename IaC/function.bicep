@description('Application name - used as prefix for resource names')
param appName string
@description('Primary location for resources')
param location string = resourceGroup().location
@description('Source branch of PR to append to dev function names - passed in via pipeline for dev environment')
param branchName string = ''
@description('Environment name')
@allowed([
  'dev'
  'test'
  'prod'
])
param environmentName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: '${substring(appName,0,10)}${uniqueString(resourceGroup().id)}' // storage accounts must be between 3 and 24 characters in length and use numbers and lower-case letters only
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: '${appName}-${environmentName}-monitor'
  location: location
  kind: 'web'
  properties: { 
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: {
     'hidden-link:/subscriptions/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/${appName}-${environmentName}${branchName}': 'Resource'
  }
}

resource funcServicePlan 'Microsoft.Web/serverfarms@2020-10-01' = {
  name: '${appName}-${environmentName}-func-plan'
  location: location
  sku: {
    name: 'Y1' 
    tier: 'Dynamic'
  }
}

resource functionApp 'Microsoft.Web/sites@2020-06-01' = {
  name: '${appName}-func-${environmentName}${branchName}'
  location: location
  kind: 'functionapp'
  properties: {
    httpsOnly: true
    serverFarmId: funcServicePlan.id
    clientAffinityEnabled: true
    siteConfig: {
      appSettings: [
        {
          'name': 'APPINSIGHTS_INSTRUMENTATIONKEY'
          'value': appInsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          'name': 'FUNCTIONS_EXTENSION_VERSION'
          'value': '~3'
        }
        {
          'name': 'FUNCTIONS_WORKER_RUNTIME'
          'value': 'dotnet'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        // WEBSITE_CONTENTSHARE will  be auto-generated - https://docs.microsoft.com/en-us/azure/azure-functions/functions-app-settings#website_contentshare
        // WEBSITE_RUN_FROM_PACKAGE will be set to 1 by func azure functionapp publish
      ]
    }
  }
}
