# Input bindings are passed in via param block.
param($Timer)

# Environment Variables
$LogTable = "Console_Status"
$KeyVaultName=$env:KeyVaultName
$vCenterURL = $env:vCenterURL
$NSXTURL = $env:NSXTURL
$HCXURL = $env:HCXURL
$CustomerID = $env:LAW_WorkSpace_ID

# KeyVault Secrets
$SharedKey=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsLAWKey" -asplaintext
$avsvCenterAdmin=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsvCenterAdmin" -asplaintext
$avsNSXTAdmin=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsNSXTAdmin" -asplaintext
$avsvCenterAdminPassword=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "AVSSDDCvCentrerAdminAccountPassword" -asplaintext
$avsNSXTAdminPassword=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsNSXTAdminPassword" -asplaintext
$avsLAWSecret=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsLAWKey" -asplaintext

#Note this example uses the cloudadmin@vsphere.local account to authenticate with both vCenter and HCX
#Note this example uses cloudadmin account to authenticate with NSXT

# The following are used for checking that environment variables and keyvault secrets are being retrieved.
# "LAWSharedKey: $sharedKey"
# "CustomerID: $CustomerID"
# "vCenterURL: $vCenterURL"
# "HCXURL: $HCXURL"
# "NSXTURL: $NSXTURL"
# "KeyVault: $KeyVaultName"
# "LogAnalyticsKey:$SharedKey”
# “avsvCenterAdmin:$avsvCenterAdmin”
# “avsNSXTAdmin:$avsNSXTAdmin”
# “avsvCenterAdminPassword:$avsvCenterAdminPassword”
# “avsNSXTAdminPassword:$avsNSXTAdminPassword”

# The following are used to verify network connectivity to the vCenter, HCX and NSXT 
# $vCenter=Test-connection $vCenterURL.trim("https://") -tcpport 443
# $VCntr=Test-connection $vCenterURL.trim("https://") -tcpport 443
# $HCX=Test-connection $HCXURL.trim("https://") -tcpport 443
# $NSXT=Test-connection $NSXTURL.trim("https://") -tcpport 443

 $VCntr=Test-connection $vCenterURL.trim("https://") -tcpport 443
 $HCX=Test-connection $HCXURL.trim("https://") -tcpport 443
 $NSXT=Test-connection $NSXTURL.trim("https://") -tcpport 443
 "VC Network connection valid: $vCntr"
 "HCX Network connection valid: $HCX"
 "NSX Network connection valid: $NSXT"

#Variables required for the function
$result = @()
$counter = 0

$ListOfSDDCs = Get-AzVmwarePrivateCloud
#$ListOfSDDCs

ForEach ($SDDCName in $ListOfSDDCs.Name) {
    
    # Get the cloud name and the resource group
    $SDDCName=$ListOfSDDCs[$counter].Name
    $RGName=$ListOfSDDCs[$counter].ResourceGroupName
    
    #Example how to get Azure resource info
    #$SDDCResourceID = get-azresource -Resourcegroupname $RGName -resourcename $SDDCName | Select-Object -ExpandProperty ResourceId
    #$DiagName =Get-AzDiagnosticSetting -ResourceId $SDDCResourceID | Select-Object -ExpandProperty Name

    # Retrieve the private cloud details (including vCenter IP)
    $privateCloud = Get-AzVmwarePrivateCloud -ResourceGroupName $RGName -Name $SDDCName
    $vCenterIP = $privateCloud.EndpointVcenterIP
    $NSXIP = $privateCloud.EndpointNsxtManagerIP
    $HCXIP = $privateCloud.EndpointHcxCloudManagerIP

    #$vCenterConnection = Invoke-Webrequest "https://$vCenterIP" -skipcertificatecheck
    #$NSXConnection = Invoke-Webrequest "https://$NSXIP" -skipcertificatecheck
    #$HCXConnection = Invoke-Webrequest "https://$HCXIP" -skipcertificatecheck

    $vCenterConnection = test-connection $vCenterIP -tcpport 443 -quiet
    $NSXConnection = test-connection $NSXIP -tcpport 443 -quiet
    $HCXConnection = test-connection $HCXIP -tcpport 443 -quiet

    $object = [PSCustomOBject]@{
        SDDC = $SDDCName
        Resource_Group = $RGName
        vCenterIP = $vCenterIP
        vCenter_Connected = $vCenterConnection
        NSXIP = $NSXIP
        NSX_Connected = $NSXConnection
        HXCIP = $HCXIP
        HCX_Connected = $HCXConnection
    }
     $result += $object
     $counter += 1  
     # This enables iterating through the SDDCs - see lines 17 & 18
}

$ResultData = $result | ConvertTo-Json -Depth 100
$ResultData

Send-LogToLogAnalytics -CustomerId $CustomerId `
                         -SharedKey $sharedKey `
                         -Log $ResultData `
                         -LogType $LogTable

                         