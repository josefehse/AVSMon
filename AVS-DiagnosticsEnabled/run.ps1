# Input bindings are passed in via param block.
param($Timer)

# Environment Variables
$LogType="AVS_DiagnosticsStatus"
$KeyVaultName=$env:KeyVaultName
$HCXURL = $env:HCXURL
$vCenterURL = $env:vCenterURL
$NSXTURL = $env:NSXTURL
$CustomerID = $env:LAW_WorkSpace_ID

# KeyVault Secrets
$SharedKey=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsLAWKey" -asplaintext
$avsvCenterAdmin=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsvCenterAdmin" -asplaintext
$avsNSXTAdmin=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsNSXTAdmin" -asplaintext
$avsvCenterAdminPassword=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "AVSSDDCvCentrerAdminAccountPassword" -asplaintext
$avsNSXTAdminPassword=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsNSXTAdminPassword" -asplaintext
$avsLAWSecret=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsLAWKey" -asplaintext
$avsTenantID=Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "avsTenantID" -asplaintext

#Note this example uses the cloudadmin@vsphere.local account to authenticate with both vCenter and HCX
#Note this example uses cloudadmin account to authenticate with NSXT

# The following are used for checking that environment variables and keyvault secrets are being retrieved.
 "LAWSharedKey: $sharedKey"
 "CustomerID: $CustomerID"
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

# "VC Network connection valid: $vCntr"
# "HC Network connection valid: $HCX"
# Create Credential Automatically for NSXT (ENABLED)

# END of the variable definitions and authentication process - this is repeatable for all powershell and URI queries.
# ___________________________________________________________________________________________________________________

#Get list of private clouds
$ListOfSDDCs = Get-AzVmwarePrivateCloud
$result = @()
$counter = 0

ForEach ($SDDCName in $ListOfSDDCs.Name) {
    
    # Get the diagnostics setting for the cloud
    $RGName=$ListOfSDDCs[$counter].ResourceGroupName
    $SDDCName=$ListOfSDDCs[$counter].Name
  
    $counter += 1
    $SDDCResourceID = get-azresource -Resourcegroupname $RGName -resourcename $SDDCName | Select-Object -ExpandProperty ResourceId
    $DiagName =Get-AzDiagnosticSetting -ResourceId $SDDCResourceID | Select-Object -ExpandProperty Name
           
    if ($DiagName) {
        $LAWworkspace = Get-AzDiagnosticSetting -ResourceId $SDDCResourceID | Select-Object -ExpandProperty WorkspaceId
        $LAWworkspace = split-path $LAWworkspace -Leaf
        $Enabled = "Yes"
    } else {
       $Enabled = "No"
       $Diagname = "-"
       $LAWworkspace = "-"
    }
    
    $object = [PSCustomOBject]@{
        SDDC = $SDDCName
        Enabled = $Enabled
        LAW_Workspace = $LAWworkspace
        Diagnostics = $DiagName
    }
     $result += $object
}

# $result 
#"___________________________________________________________"


$ResultData = $result | ConvertTo-Json -Depth 100
$ResultData

 Send-LogToLogAnalytics -CustomerId $CustomerId `
                         -SharedKey $sharedKey `
                         -Log $ResultData `
                         -LogType $LogType

