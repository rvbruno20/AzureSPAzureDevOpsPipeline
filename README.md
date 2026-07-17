# AzureSPAzureDevOpsPipeline

Azure DevOps pipeline for rotating Azure AD app registration secrets, storing the new values in Azure Key Vault, and optionally posting a notification payload to an Azure Logic App.

## Overview

The repository contains an Azure DevOps pipeline plus PowerShell automation that:

- checks whether an app registration secret is expired or close to expiration
- creates a new secret through Microsoft Graph when rotation is required
- stores the generated secret value in Azure Key Vault
- generates an email-ready notification payload and optionally sends it to an Azure Logic App endpoint

The pipeline is scheduled to run weekly and processes each configured app registration independently.

## Repository Structure

- [azure-pipeline.yml](azure-pipeline.yml): pipeline entrypoint and application list
- [pipeline/structure/pipeline_structure.yml](pipeline/structure/pipeline_structure.yml): shared stage and job template
- [scripts/Test-AppRegistrationSecretExpiration.ps1](scripts/Test-AppRegistrationSecretExpiration.ps1): detects whether a secret needs rotation
- [scripts/New-AppRegistrationSecret.ps1](scripts/New-AppRegistrationSecret.ps1): creates a new app registration secret
- [scripts/Save-AppRegistrationSecretToKeyVault.ps1](scripts/Save-AppRegistrationSecretToKeyVault.ps1): saves the secret into Azure Key Vault
- [scripts/Send-AppRegistrationRotationNotification.py](scripts/Send-AppRegistrationRotationNotification.py): builds the notification payload and optionally posts it to a Logic App URL

## Execution Flow

1. [azure-pipeline.yml](azure-pipeline.yml) runs on the configured weekly schedule and iterates over `parameters.applications`.
2. Each application expands the shared template in [pipeline/structure/pipeline_structure.yml](pipeline/structure/pipeline_structure.yml).
3. [scripts/Test-AppRegistrationSecretExpiration.ps1](scripts/Test-AppRegistrationSecretExpiration.ps1) inspects the current password credentials and sets the pipeline output variable `depend`.
4. If `depend` is `true`, [scripts/New-AppRegistrationSecret.ps1](scripts/New-AppRegistrationSecret.ps1) creates a new secret and exports `secretValue` as a secret output variable.
5. [scripts/Save-AppRegistrationSecretToKeyVault.ps1](scripts/Save-AppRegistrationSecretToKeyVault.ps1) writes that value to Azure Key Vault.
6. [scripts/Send-AppRegistrationRotationNotification.py](scripts/Send-AppRegistrationRotationNotification.py) generates an email-oriented payload and posts it to the configured Logic App URL when one is provided.

## Azure DevOps Requirements

The pipeline expects an Azure DevOps variable group named `secret-management-pipeline` and an Azure service connection referenced by `$(azureServiceConnection)`.

Current variable usage in the checked-in pipeline/scripts includes:

- `azureServiceConnection`
- `vgKeyVaultName`
- `vgKeyVaultResourceGroup`
- `vgKeyVaultSubscription`
- `vgLogicAppUrl` as an optional Logic App webhook endpoint for notifications

## Runtime And Azure Requirements

The scripts currently rely on:

- Azure PowerShell in the Azure DevOps `AzurePowershell@5` task
- Python 3.x in Azure DevOps for notification payload generation
- Microsoft Graph PowerShell modules
- permissions to read app registrations, create application passwords, and update Azure Key Vault secrets

`Test-AppRegistrationSecretExpiration.ps1` and `New-AppRegistrationSecret.ps1` install `Microsoft.Graph` when it is not already available.

The notification step uses only the Python standard library. If `vgLogicAppUrl` is empty or not configured yet, the job logs the generated payload and exits successfully.

## Scheduling And Target Applications

The default pipeline configuration:

- does not trigger on commits
- runs on Mondays at 06:00 UTC
- uses `ubuntu-latest`
- rotates secrets for the app registrations listed in `parameters.applications`

Update the `parameters.applications` list in [azure-pipeline.yml](azure-pipeline.yml) to target the correct service principals.

## Notes

- The checked-in implementation is Azure DevOps YAML plus PowerShell, with one Python notification script.
- If you change pipeline variable names, script parameters, or job output names, keep the YAML and PowerShell files aligned.
