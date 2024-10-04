// This bicep template will contain the setup for the AVS Monitoring solution
// It will be composed of:
// - A Log Analytics Workspace
// - An Azure Function to collect data from the AVS Monitoring API
// The Azure function will be of the Premium SKU to allow for longer execution times and vnet integration
// The Azure function will be configured to run every 15 minutes (?)
// The Azure function will be configured to write to the Log Analytics workspace
targetScope = 'resourceGroup'
param storageAccountName string
param location string = resourceGroup().location
param functionname string = 'avsmonbami1t'
param keyvaultName string
param useExistingKeyVault bool = false
//param vnetId string //future use
param subnetId string
param collectTelemetry bool = false
param createNewLogAnalyticsWS bool = true
param createNewStorageAccount bool
param logAnalyticsWorkspaceName string
param Tags object = {
  environment: 'dev'
  project: 'avsmon'
}

param avsNSXTAdmin string
@secure()
param avsNSXTAdminPassword string
param avsvCenterAdmin string
@secure()
param avsvCenterAdminPassword string
param vCenterFQDN string

param sasExpiry string = dateTimeAdd(utcNow(), 'PT2H')

var tempfilename = 'functions.zip.tmp'
var filename='functions.zip'
var functionsContainerName = 'functions'
var telemetryInfo = json(loadTextContent('./telemetry.json'))
var userIdentityName = '${functionname}-identity'
var sasConfig = {
  signedResourceTypes: 'sco'
  signedPermission: 'r'
  signedServices: 'b'
  signedExpiry: sasExpiry
  signedProtocol: 'https'
  keyToSign: 'key2'
}

var functionUserAssignedIdentityRoles= [
  '4633458b-17de-408a-b874-0445c86b69e6'  // keyvault reader role
  'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'  // Storage Blob Data Owner
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe'  // storage blob data reader role
  '92aaf0da-9dab-42b6-94a3-d43ce8d16293'  // log analytics contributor role
]
var functionSystemAssignedIdentityRoles= [
  'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'  // Storage Blob Data Owner
]
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

resource userManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: userIdentityName
  location: location
  tags: Tags
}

module userIdentityRoleAssignmentRG './modules/roleassignment.bicep' = [for (roledefinitionId, i) in functionUserAssignedIdentityRoles:  {
  name: '${userIdentityName}-${i}-RG'
  params: {
    resourcename: userIdentityName
    principalId: userManagedIdentity.properties.principalId
    roleDefinitionId: roledefinitionId
    roleShortName: roledefinitionId
  }
}]

resource vault 'Microsoft.KeyVault/vaults@2024-04-01-preview' = if (!useExistingKeyVault) {
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
resource existingVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = if (useExistingKeyVault) {
  name: keyvaultName
}
// Add secret from function
module kvsecret1 './modules/kvsecret.bicep' = {
  name: 'avsNSXTAdmin'
  params: {
    secretname: 'avsNSXTAdmin'
    secretvalue: avsNSXTAdmin
    Tags: Tags
    vaultName: useExistingKeyVault ? existingVault.name : vault.name
  }
}
module kvsecret2 './modules/kvsecret.bicep' = {
  name: 'avsNSXTAdminPassword'
  params: {
    secretname: 'avsNSXTAdminPassword'
    secretvalue: avsNSXTAdminPassword
    Tags: Tags
    vaultName: useExistingKeyVault ? existingVault.name : vault.name
  }
}

module kvsecret3 './modules/kvsecret.bicep' = {
  name: 'avsvCenterAdmin'
  params: {
    secretname: 'avsvCenterAdmin'
    secretvalue: avsvCenterAdmin
    Tags: Tags
    vaultName: useExistingKeyVault ? existingVault.name : vault.name
  }
}

module kvsecret4 './modules/kvsecret.bicep' = {
  name: 'avsvCenterAdminPassword'
  params: {
    secretname: 'avsvCenterAdminPassword'
    secretvalue: avsvCenterAdminPassword
    Tags: Tags
    vaultName: useExistingKeyVault ? existingVault.name : vault.name
  }
}

module kvsecret5 './modules/kvsecret.bicep' = {
  name: 'vCenterFQDN'
  params: {
    secretname: 'vCenterFQDN'
    secretvalue: vCenterFQDN
    Tags: Tags
    vaultName: useExistingKeyVault ? existingVault.name : vault.name
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = if (createNewStorageAccount) {
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
    resource container1 'containers'={
      name: functionsContainerName
      properties: {
        immutableStorageWithVersioning: {
            enabled: false
        }
        denyEncryptionScopeOverride: false
        defaultEncryptionScope: '$account-encryption-key'
        publicAccess: 'None'
      }
    }
  }
  resource fileshare 'fileServices' = {
    name: 'default'
    resource fileshare 'shares' = {
      name: storageAccountName
      properties: {
        shareQuota: 1024
        accessTier: 'TransactionOptimized'
        enabledProtocols: 'SMB'
      }
    }
  }
}
resource existingStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = if (!createNewStorageAccount) {
  name: storageAccountName
}

resource kvsecret6 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  name: 'azurefilesconnectionstring'
  tags: Tags
  parent: vault
  properties: {
    attributes: {
      enabled: true
    }
    contentType: 'string'
    value: 'DefaultEndpointsProtocol=https;AccountName=${createNewStorageAccount ? storageAccount.name : existingStorageAccount.name};AccountKey=${listKeys(createNewStorageAccount ? storageAccount.id: existingStorageAccount.id, createNewStorageAccount ? storageAccount.apiVersion : existingStorageAccount.apiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
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
      type: 'SystemAssigned, UserAssigned'
      userAssignedIdentities: {
          '${userManagedIdentity.id}': {}
      }
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
      keyVaultReferenceIdentity: userManagedIdentity.id
      vnetRouteAllEnabled: true
      virtualNetworkSubnetId: subnetId
  }
}

// // Assign the required permissions to the function app once it is created
// resource functionapproleassignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (roledefinitionId, i) in functionSystemAssignedIdentityRoles:  {
//   name: guid(subscription().subscriptionId, functionname, 'functionapproleassignment-${i}')
//   properties: {
//     principalId: azfunctionsite.identity.principalId
//     roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Authorization/roleDefinitions/${roledefinitionId}'
//   }
// }]

module SystemIdentityRoleAssignment './modules/roleassignment.bicep' = [for (roledefinitionId, i) in functionSystemAssignedIdentityRoles:  {
  name: 'SystemAssignedIdentityRole-${i}'
  params: {
    resourcename: azfunctionsite.name
    principalId: azfunctionsite.identity.principalId
    roleDefinitionId: roledefinitionId
    roleShortName: roledefinitionId
  }
}]
resource azfunctionsiteconfig 'Microsoft.Web/sites/config@2021-03-01' = {
  name: 'appsettings'
  parent: azfunctionsite
  properties: {
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=azurefilesconnectionstring)'
    AzureWebJobsStorage__accountName: createNewStorageAccount ? storageAccount.name : existingStorageAccount.name
    WEBSITE_CONTENTSHARE : createNewStorageAccount ? storageAccount.name : existingStorageAccount.name
    MSI_CLIENT_ID: userManagedIdentity.properties.clientId
    FUNCTIONS_WORKER_RUNTIME:'powershell'
    FUNCTIONS_EXTENSION_VERSION:'~4'
    ResourceGroup: resourceGroup().name
    APPINSIGHTS_INSTRUMENTATIONKEY: reference(appinsights.id, '2020-02-02-preview').InstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: 'InstrumentationKey=${reference(appinsights.id, '2020-02-02-preview').InstrumentationKey}'
    ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    WEBSITE_SKIP_CONTENTSHARE_VALIDATION: '1'
  }
}
  
resource appinsights 'Microsoft.Insights/components@2020-02-02' = {
  name: functionname
  tags: Tags
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    WorkspaceResourceId: law.id
  }
}
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'deployscript-Function-${functionname}'
  dependsOn: [
    azfunctionsiteconfig
  ]
  tags: Tags
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userManagedIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.42.0'
    timeout: 'PT5M'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: createNewStorageAccount ? storageAccount.name : existingStorageAccount.name
      }
      {
        name: 'CONTENT'
        value: loadFileAsBase64('./functions/functions.zip')
      }
    ]
    scriptContent: 'echo "$CONTENT" > ${tempfilename} && cat ${tempfilename} | base64 -d > ${filename} && az storage blob upload -f ${filename} -c ${functionsContainerName} -n ${filename} --auth-mode login --overwrite true'
  }
}
resource deployfunctions 'Microsoft.Web/sites/extensions@2021-02-01' = {
  parent: azfunctionsite
  dependsOn: [
    deploymentScript
  ]
  name: 'MSDeploy'
  properties: {
    packageUri: '${createNewStorageAccount ? storageAccount.properties.primaryEndpoints.blob : existingStorageAccount.properties.primaryEndpoints.blob}${functionsContainerName}/${filename}?${(createNewStorageAccount ? storageAccount.listAccountSAS(storageAccount.apiVersion, sasConfig).accountSasToken : existingStorageAccount.listAccountSAS(storageAccount.apiVersion, sasConfig).accountSasToken)}'
  }
}
resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = if(createNewLogAnalyticsWS) {
  name: logAnalyticsWorkspaceName
  location: location
  tags: Tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

module telemetry 'nested_telemetry.bicep' =  if (collectTelemetry) {
  name: telemetryInfo.customerUsageAttribution.SolutionIdentifier
  scope: resourceGroup()
  params: {}
}
