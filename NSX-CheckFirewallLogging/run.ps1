# Define the NSX Manager URL and credentials
$nsxManagerUrl = "https://nsx-manager.example.com"
$username = "your_username"
$password = "your_password"

# Convert credentials to a secure string
$securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
$credentials = New-Object System.Management.Automation.PSCredential($username, $securePassword)

# Define the headers for the REST API call
$headers = @{
    "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($username):$($password)"))
    "Content-Type" = "application/json"
}

# Define the REST API endpoint for firewall rules
$apiEndpoint = "$nsxManagerUrl/api/v1/firewall/sections"

# Get the firewall sections
$response = Invoke-RestMethod -Uri $apiEndpoint -Headers $headers -Method Get

# Initialize an array to hold the results
$result = @()

# Loop through each section and check the rules for logging status
foreach ($section in $response.results) {
    $sectionId = $section.id
    $sectionName = $section.display_name
    $rulesEndpoint = "$nsxManagerUrl/api/v1/firewall/sections/$sectionId/rules"
    $rulesResponse = Invoke-RestMethod -Uri $rulesEndpoint -Headers $headers -Method Get
    
    foreach ($rule in $rulesResponse.results) {
        if ($rule.logging.enabled -eq $false) {
            $result += [PSCustomObject]@{
                SectionName = $sectionName
                RuleId = $rule.id
                RuleName = $rule.display_name
                LoggingEnabled = $rule.logging.enabled
            }
        }
    }
}

# Convert the result to JSON
$jsonArray = $result | ConvertTo-Json -Depth 10

# Print the output
Write-Output "JSON Array Output:"
Write-Output $jsonArray

# Export JSON to a file
$jsonArray | Set-Content -Path "NSXFirewallRulesWithoutLogging.json"

Write-Output "Firewall rules without logging enabled have been listed and saved to NSXFirewallRulesWithoutLogging.json"
