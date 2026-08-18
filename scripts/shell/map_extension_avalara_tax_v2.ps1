# Seed for a more advanced version which can take arguments by defalt or prompt for them
param(
    [string]$StoreId,
    [string]$TargetOrg
)

# Prompt for StoreId if not supplied
if ([string]::IsNullOrWhiteSpace($StoreId)) {
    $StoreId = Read-Host "Enter the Salesforce WebStore ID"
}

# Prompt for TargetOrg if not supplied
if ([string]::IsNullOrWhiteSpace($TargetOrg)) {
    $TargetOrg = Read-Host "Enter the Salesforce target org username or alias"
}

# Validate
if ([string]::IsNullOrWhiteSpace($StoreId)) {
    Write-Error "A WebStore ID is required."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($TargetOrg)) {
    Write-Error "A Salesforce target org username or alias is required."
    exit 1
}

Write-Host "WebStore ID: $StoreId"
Write-Host "Target Org:  $TargetOrg"