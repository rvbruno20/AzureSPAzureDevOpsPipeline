# ==============================
# Parameters
# ==============================

param(
    [Parameter(Mandatory=$true)]
    [string]$appRegistration,

    [Parameter(Mandatory=$true)]
    [securestring]$passwordValue,

    [Parameter(Mandatory=$true)]
    [string]$keyVaultName,

    [Parameter(Mandatory=$true)]
    [string]$keyVaultRG,

    [Parameter(Mandatory=$true)]
    [string]$keyVaultSubName
)

# ==============================
# Error Action
# ==============================

$ErrorActionPreference = 'Stop'

# ==============================
# Change Subscription
# ==============================

Set-AzContext -Subscription $keyVaultSubName | Out-Null

# ==============================
# Find Azure KV
# ==============================

Write-Output $appRegistration

try {
    
    $keyVault = Get-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $keyVaultRG

    if ($null -ne $keyVault) {
    
        Write-Output "Azure Key Vault [$($keyVault.VaultName)] has been identified."

        $myIp = (Invoke-WebRequest -Uri 'https://api.ipify.org').Content.Trim()
        Write-Output "Whitelisting public IP [$myIp] for Key Vault access."

        # Whitelist IP
        Add-AzKeyVaultNetworkRule -VaultName $keyVault.VaultName -IpAddressRange $myIp

        # Check if entry is already present
        $secretValidation = Get-AzKeyVaultSecret -VaultName $keyVaultName | Where-Object { $_.Name -eq $appRegistration }
        
        if ($null -ne $secretValidation) {
            
            Write-Output "A secret with the name [$($appRegistration)] already exist. Updating it with the new secret..."

            Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $appRegistration -SecretValue $passwordValue

        }else{

            Write-Output "No secret with the name [$($appRegistration)] exist. Creating a new entry now..."

            Set-AzKeyVaultSecret -VaultName $keyVaultName -Name $appRegistration -SecretValue $passwordValue

        }

        $objectValidation = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $appRegistration

        if ($null -ne $objectValidation) {
            
            Write-Output "Secret has been created successfuly!"

        }else{

            Write-Output "Secret has not been created... Closing script now..."
            throw ("Secret has not been created... Closing script now...")

        }

        # Remove Whitelisting
        Remove-AzKeyVaultNetworkRule -VaultName $KeyVault.VaultName -IpAddressRange $myIp

    }else {
        
        Write-Output "Key Vault [$($keyVaultName)] not found... Closing script now..."
        throw ("Key Vault [$($keyVaultName)] not found... Closing script now...")

    }

}
catch {
    Write-Error "An error as occured:`n$_"
}