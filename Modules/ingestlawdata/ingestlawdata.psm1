function new-discoveryData {
    param (
        [Parameter(Mandatory = $true)]
        [string]$instanceName,
        [Parameter(Mandatory = $true)]
        [object]$data,
        [Parameter(Mandatory = $true)]
        [string]$DcrImmutableId,
        [Parameter(Mandatory = $true)]
        [string]$tableName,
        [Parameter(Mandatory = $false)]
        [string]$streamname,
        [Parameter(Mandatory = $false)]
        [bool]$localtest,
        [Parameter(Mandatory = $false)]
        [string]$appId,
        [Parameter(Mandatory = $false)]
        [string]$appSecret
    )
    #$dceId="https://amp-mcp1-dce-canadacentral-6f18.canadacentral-1.ingest.monitor.azure.com"
    # get DCE URL from the DCE Id, using a tag.
    $DCE=Get-AzDataCollectionEndpoint #| Where-Object {$_.Tag['instanceName'] -eq $instanceName}
    $tenantId=(Get-AzContext).Tenant.Id
    if ($null -eq $DCE) {
        Write-Error "No DCE found"
        return $null
    }
    else {
        Write-host "Found DCE $($DCE.Name) with id $($DCE.Id)"
        $dceurl=$DCE.LogIngestionEndpoint
        Write-host "DCE URL: $dceurl"
    }
    if ($localtest) {
        Add-Type -AssemblyName System.Web
        $scope = [System.Web.HttpUtility]::UrlEncode("https://monitor.azure.com//.default")   
        $body = "client_id=$appId&scope=$scope&client_secret=$appSecret&grant_type=client_credentials";
        $headers = @{"Content-Type" = "application/x-www-form-urlencoded" };
        $uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
        $bearerToken = (Invoke-RestMethod -Uri $uri -Method "Post" -Body $body -Headers $headers).access_token
    }
    else {
        $scope="https://monitor.azure.com"
        $bearerToken = (Get-AzAccessToken -ResourceUrl $scope -TenantId $tenantId ).Token
        #$bearerToken
    }
    # When using a managed identity, use the following line to get the token:
    # $scope = [System.Web.HttpUtility]::UrlEncode("https://monitor.azure.com//.default")   
    # if data is a hashtable, convert it to an array of objects
    if ($data.count -eq 1) {
        $body = "[$($data | ConvertTo-Json -Depth 10)]"
    }
    else {
        $body = $data | ConvertTo-Json 
    }
    
    $body
    if ([string]::IsNullOrEmpty($streamname)) {
        $streamname=("Custom-$tableName") #.Replace("_CL","")
        Write-host "No stream name provided, using default stream name. $streamname"
    }
    else {
        Write-host "Using stream name $streamname"
    }
    #$headers = @{"Authorization" = "Bearer $bearerToken"; "Content-Type" = "application/json" };
    # The stream name is what counts here and needs to match the stream name in the DCR.
    $uri = "$dceurl/dataCollectionRules/$DcrImmutableId/streams/$streamname"+"?api-version=2023-01-01";
    Write-host "Sending data to DCR at $uri"
    try {
        #$uploadResponse = Invoke-RestMethod -Uri $uri -Method "Post" -Body $body -Headers $headers;
        $uploadResponse=Invoke-RestMethod -Method Post -Uri $uri -Headers @{"Authorization"="Bearer $bearerToken"} -Body $body -ContentType "application/json"   
        Write-host "Data sent to DCR successfully."
        Write-host "Response: $($uploadResponse | ConvertTo-Json -Depth 10)"
    }
    catch {
        Write-Error "Error sending data to DCR: $_"
        return $null
    }
}
