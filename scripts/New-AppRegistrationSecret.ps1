# ==============================
# Parameters
# ==============================

param(
    [Parameter(Mandatory=$true)]
    [string]$appRegistration
)

# ==============================
# Confirm Microsoft Graph Module is available
# ==============================

if (-not (Get-Module -ListAvailable Microsoft.Graph)) {
    Install-Module Microsoft.Graph -Scope CurrentUser -Force -Repository PSGallery
}

# ==============================
# Move from ARM to Graph
# ==============================

$token = (Get-AzAccessToken -ResourceTypeName MSGraph).Token

$plain = if ($tokSecure -is [System.Security.SecureString]) {
          (New-Object System.Net.NetworkCredential('', $token)).Password
        } else { $token }

Import-Module Microsoft.Graph.Authentication
Connect-MgGraph -AccessToken $plain -NoWelcome

$ctx = Get-MgContext

Write-Output "Connected to tenant: $($ctx.TenantId); App/Acct: $($ctx.AppName)"

# ==============================
# Generate new secret
# ==============================

Write-Output "Fetching application -> '$appRegistration'"

$application = Get-MgApplication | Where-Object { $_.DisplayName -eq $appRegistration }

$SecretDescription = "Azure DevOps Pipeline"
$SecretEndDate = (Get-Date).AddMonths(12)

$passwordCred = @{
    displayName = $SecretDescription
    endDateTime = $SecretEndDate
}

$NewSecret = Add-MgApplicationPassword -ApplicationId $application.Id -PasswordCredential $passwordCred

$secretValue = $NewSecret.SecretText

# Export Secret

Write-Output "##vso[task.setvariable variable=secretValue;isOutput=true;isSecret=true]$secretValue"

# ==============================
# Finalizing Script
# ==============================

Write-Output "Disconnecting from Microsoft Graph..."

Disconnect-MgGraph

Write-Output "Script has finished running."