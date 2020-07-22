$resourceGroupName = "ACI" # <- Replace with your value
$location = "australiaeast" # <- This must be a location that can host Azure Container Instances
$storageAccountName = "deploymentscript474694" # <- Unique storage account name
$userManagedIdentity = "scriptRunner" # <- Change this if you want

New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName || New-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -Location $location -SkuName Standard_LRS

$uamiObject = New-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $userManagedIdentity -Location $location

New-AzRoleAssignment -ObjectId $uamiObject.PrincipalId -RoleDefinitionName Reader
New-AzRoleAssignment -ObjectId $uamiObject.PrincipalId -RoleDefinitionName "Virtual Machine Contributor"

$policies = Get-ChildItem -Path .\Policies -Recurse -File

foreach ($policy in $policies) {

    if ($policy.BaseName) {
        Write-Output "Deploying policy $($policy.BaseName)"
        $policyParameters = $null
        $params = $null

        $policyObj = Get-Content $policy | ConvertFrom-Json | Select-Object -ExpandProperty properties

        (Get-Content $policy | ConvertFrom-Json | Select-Object -ExpandProperty properties).policyRule `
        | ConvertTo-Json -Depth 100 | Out-File tmp_$($policyObj.Name).json

        $policyRules = Get-Content tmp_$($policyObj.Name).json -Raw && Remove-Item tmp_$($policyObj.Name).json -Force

        (Get-Content $policy | ConvertFrom-Json | Select-Object -ExpandProperty properties).parameters `
        | ConvertTo-Json -Depth 100 | Out-File tmp_$($policyObj.Name).json

        if ((Get-Content tmp_$($policyObj.Name).json | Measure-Object -Line).Lines -gt 1 ) {
            $policyParameters = Get-Content tmp_$($policyObj.Name).json -Raw
            $params = @{
                Verbose   = $true
                Parameter = $policyParameters
            }
        }
        else {
            $params = @{
                Verbose = $true
            }
        }

        Remove-Item tmp_$($policyObj.Name).json -Force

        New-AzPolicyDefinition -Name $policyObj.name `
            -DisplayName $policyObj.displayName `
            -Description $policyObj.description `
            -Policy $policyRules `
            -Mode $policyObj.mode `
            -Metadata ($policyObj.metadata | ConvertTo-Json) `
            @params

        $params = $null
    }
    
}

Write-Output "ACIResourceGroup --- $resourceGroupName"
Write-Output "StorageAccountId --- $((Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName).Id)"
Write-Output "StorageAccountName --- $storageAccountName"
Write-Output "RemediationIdentity --- $($uamiObject.Id)"




