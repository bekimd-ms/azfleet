Param(
    [string] $ResourceGroupName,
    [string] $UserName,
    [string] $Password
)

$storageEndpointSuffix= ((Get-AzContext).Environment | Get-AzEnvironment).StorageEndpointSuffix

New-AzResourceGroupDeployment -Name "controllerdeployment" -ResourceGroupName $ResourceGroupName `
                              -TemplateFile .\templates\controller.template.json `
                              -StorageEndpointSuffix $storageEndpointSuffix `
                              -vmAdminUserName $UserName -vmAdminPassword $Password `
                              -verbose

                              