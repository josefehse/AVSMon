// This bicep template will contain the setup for the AVS Monitoring solution
// It will be composed of:
// - A Log Analytics Workspace
// - An Azure Function to collect data from the AVS Monitoring API
// The Azure function will be of the Premium SKU to allow for longer execution times and vnet integration
// The Azure function will be configured to run every 15 minutes (?)
// The Azure function will be configured to write to the Log Analytics workspace
param storageAccountName string
param location string = resourceGroup().location
param functionname string = 'avsmonbami1t'
param keyvaultName string
param Tags object = {
  environment: 'dev'
  project: 'avsmon'
}
param vnetId string
param subnetId string
param createDNSzone bool = true

param logAnalyticsWorkspaceName string
param appInsightsLocation string

// resource PrivateDNSZoneforwebsites 'Microsoft.Network/privateDnsZones@2024-06-01' = if (createDNSzone) {
//   name: 'privatelink.azurewebsites.net'
//   location: 'global'
//   tags: Tags
//   properties: {
//   }
// }
// resource pdnszoneregistration 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (createDNSzone) {
//   name: 'linktovnet'
//   parent: PrivateDNSZoneforwebsites
//   location: 'global'
//   properties: {
//     registrationEnabled: true
//     virtualNetwork: {
//       id: vnetId
//     }
//   }
// }

resource vault 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: keyvaultName
  location: location
  tags: Tags
  properties: {
    sku: {
      family: 'A'
      name:  'standard'
    }
    tenantId: subscription().tenantId
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enableRbacAuthorization: true
    provisioningState: 'Succeeded'
    publicNetworkAccess: 'Enabled'
    enablePurgeProtection: true //CAF
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: Tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
  }
  resource blobServices 'blobServices'={
    name: 'default'
    properties: {
        cors: {
            corsRules: []
        }
        deleteRetentionPolicy: {
            enabled: false
        }
    }
    // resource container1 'containers'={
    //   name: 'appinstall'
    //   properties: {
    //     immutableStorageWithVersioning: {
    //         enabled: false
    //     }
    //     denyEncryptionScopeOverride: false
    //     defaultEncryptionScope: '$account-encryption-key'
    //     publicAccess: 'None'
    //   }
    // }
    // resource container2 'containers'={
    //   name: 'applications'
    //   properties: {
    //     immutableStorageWithVersioning: {
    //         enabled: false
    //     }
    //     denyEncryptionScopeOverride: false
    //     defaultEncryptionScope: '$account-encryption-key'
    //     publicAccess: 'None'
    //   }
    // }
  }
}
// private endpoint for the function app
// resource privateendpoint 'Microsoft.Network/privateEndpoints@2021-03-01' = {
//   name: '${functionname}-pe'
//   location: location
//   tags: Tags
//   properties: {
//     subnet: {
//       id: subnetId
//     }
//     privateLinkServiceConnections: [
//       {
//         name: '${functionname}-plsc'
//         properties: {
//           privateLinkServiceId: resourceId('Microsoft.Web/sites', '${functionname}')
//           groupIds: [
//             'WEBSITE'
//           ]
//         }
//       }
//     ]
//     customDnsConfigs: [
//       {
//         fqdn: '${functionname}.azurewebsites.net'
//         ipAddresses: []
//       }
//     ]
//   }
// }
// Azure premium function app with vnet integestion and integration
resource serverfarm 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${functionname}-farm'
  location: location
  tags: Tags
  sku: {
    name:'EP1'
    tier: 'ElasticPremium'
    size: 'EP1'
    family: 'EP'
    capacity: 1
  }
  properties:{
    elasticScaleEnabled: true
  }
  kind: 'elastic'
}

resource azfunctionsite 'Microsoft.Web/sites@2023-12-01' = {
  name: functionname
  location: location
  kind: 'functionapp'
  tags: Tags
  identity: {
      type: 'SystemAssigned'
      // userAssignedIdentities: {
      //     '${userManagedIdentity}': {}
      // }
  }  
  properties: {
      enabled: true      
      hostNameSslStates: [
          {
              name: '${functionname}.azurewebsites.net'
              sslState: 'Disabled'
              hostType: 'Standard'
          }
          {
              name: '${functionname}.azurewebsites.net'
              sslState: 'Disabled'
              hostType: 'Repository'
          }
      ]
      serverFarmId: serverfarm.id
      reserved: false
      isXenon: false
      hyperV: false
      siteConfig: {
          numberOfWorkers: 1
          acrUseManagedIdentityCreds: false
          alwaysOn: false
          ipSecurityRestrictions: [
              {
                  ipAddress: 'Any'
                  action: 'Allow'
                  priority: 1
                  name: 'Allow all'
                  description: 'Allow all access'
              }
          ]
          scmIpSecurityRestrictions: [
              {
                  ipAddress: 'Any'
                  action: 'Allow'
                  priority: 1
                  name: 'Allow all'
                  description: 'Allow all access'
              }
          ]
          http20Enabled: false
          functionAppScaleLimit: 200
          minimumElasticInstanceCount: 1
          minTlsVersion: '1.2'
          cors: {
              allowedOrigins: [
                  'https://portal.azure.com'
              ]
              supportCredentials: true
          }  
      }
      scmSiteAlsoStopped: false
      clientAffinityEnabled: false
      clientCertEnabled: false
      clientCertMode: 'Required'
      hostNamesDisabled: false
      containerSize: 1536
      dailyMemoryTimeQuota: 0
      httpsOnly: true
      redundancyMode: 'None'
      storageAccountRequired: false
      keyVaultReferenceIdentity: 'SystemAssigned'
  }
}
var functionSystemAssignedIdentityRoles= [
  '4633458b-17de-408a-b874-0445c86b69e6'   //keyvault reader role
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'   //log analytics contributor role
  'b24988ac-6180-42a0-ab88-20f7382dd24c'   //storage blob data contributor role
//Azure log analytics reader
'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'  //log analytics reader role
]
// Assign the required permissions to the function app once it is created
resource functionapproleassignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (roledefinitionId, i) in functionSystemAssignedIdentityRoles:  {
  name: guid(subscription().subscriptionId, functionname, 'functionapproleassignment-${i}')
  properties: {
    principalId: azfunctionsite.identity.principalId
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Authorization/roleDefinitions/${roledefinitionId}'
  }
}]

resource azfunctionsiteconfig 'Microsoft.Web/sites/config@2021-03-01' = {
  name: 'appsettings'
  parent: azfunctionsite
  // dependsOn: [
  //   roleAssignment
  // ]
  properties: {
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING:'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
    AzureWebJobsStorage:'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
    WEBSITE_CONTENTSHARE : storageAccount.name
    FUNCTIONS_WORKER_RUNTIME:'powershell'
    FUNCTIONS_EXTENSION_VERSION:'~4'
    ResourceGroup: resourceGroup().name
    APPINSIGHTS_INSTRUMENTATIONKEY: reference(appinsights.id, '2020-02-02-preview').InstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: 'InstrumentationKey=${reference(appinsights.id, '2020-02-02-preview').InstrumentationKey}'
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
  }
}

resource appinsights 'Microsoft.Insights/components@2020-02-02' = {
  name: functionname
  tags: Tags
  location: appInsightsLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    WorkspaceResourceId: law.id
  }
}

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: Tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

