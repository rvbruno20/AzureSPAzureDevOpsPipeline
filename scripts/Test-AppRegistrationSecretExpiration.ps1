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
# Fetching secrets
# ==============================

Write-Output "Fetching application -> '$appRegistration'"

$application = Get-MgApplication | Where-Object { $_.DisplayName -eq $appRegistration }

$date = Get-Date

if ($application.PasswordCredentials.Count -gt 0) {
    
    Write-Output "Secrets identified for '$appRegistration' "

    if ($application.PasswordCredentials.Count -gt 1) {
        
        Write-Output "A total of [$($application.PasswordCredentials.Count) secrets, were found.]"
        Write-Output "Identifying the latest secret."

        $secret = $application.PasswordCredentials[0]

        $secretEndDate = $secret.EndDateTime

        $sumDays = ($secretEndDate - $date).Days

        if ($sumDays -lt 0) {
            
            Write-Output "Secret [$($secret.KeyId)] has expired. New secret needs to be generated..."

            $depend = "true"

            Write-Output "##vso[task.setvariable variable=depend;isOutput=true]$depend"
        }elseif ($sumDays -le 30) {
            
            Write-Output "Secret [$($secret.KeyId)] is about to expire. New secret needs to be generated..."

            $depend = "true"

            Write-Output "##vso[task.setvariable variable=depend;isOutput=true]$depend"
        }elseif ($sumDays -gt 30) {

            Write-Output "App Registration [$($appRegistration)] require no new secrets. "

            $depend = "false"

            Write-Output "##vso[task.setvariable variable=depend;isOutput=true]$depend"
        }
    }
    else{

        $secret = $application.PasswordCredentials

        Write-Output "Analyzing secret [$($secret.KeyId)]"

        $secretEndDate = $secret.EndDateTime

        $sumDays = ($secretEndDate - $date).Days

        if ($sumDays -lt 0) {
            
            Write-Output "Secret [$($secret.KeyId)] has expired. New secret needs to be generated..."

            $depend = "true"

            Write-Output "##vso[task.setvariable variable=depend;isOutput=true]$depend"
        }elseif ($sumDays -le 30) {
            
            Write-Output "Secret [$($secret.KeyId)] is about to expire. New secret needs to be generated..."

            $depend = "true"

            Write-Output "##vso[task.setvariable variable=depend;isOutput=true]$depend"
        }elseif ($sumDays -gt 30) {

            Write-Output "App Registration [$($appRegistration)] require no new secrets. "

            $depend = "false"

            Write-Output "##vso[task.setvariable variable=depend;isOutput=true]$depend"
        }

    }

}
else{

    Write-Output "No secrets where identified for '$appRegistration'"

}

# ==============================
# Finalizing Script
# ==============================

Write-Output "Disconnecting from Microsoft Graph..."

Disconnect-MgGraph

Write-Output "Script has finished running."
