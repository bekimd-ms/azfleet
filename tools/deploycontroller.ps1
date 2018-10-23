Param(
    [string] $ResourceGroupName,
    [string] $UserName,
    [string] $Password
)

$storageEndpointSuffix= ((Get-AzureRmContext).Environment | Get-AzureRmEnvironment).StorageEndpointSuffix

New-AzureRmResourceGroupDeployment -Name "controllerdeployment" -ResourceGroupName $ResourceGroupName `
                                   -TemplateFile .\md\controller.template.json `
                                   -StorageEndpointSuffix $storageEndpointSuffix `
                                   -vmAdminUserName $UserName -vmAdminPassword $Password `
                                   -verbose