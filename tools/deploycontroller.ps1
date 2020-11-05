Param(
    [string] $ResourceGroupName,
    [string] $OSType,
    [string] $UserName,
    [string] $Password
)

$templateFile = ".\templates\controller.template\controller.template." + $OSType + ".json"
$storageEndpointSuffix= ((Get-AzContext).Environment | Get-AzEnvironment).StorageEndpointSuffix

New-AzResourceGroupDeployment -Name "controllerdeployment" -ResourceGroupName $ResourceGroupName `
                              -TemplateFile $templateFile `
                              -StorageEndpointSuffix $storageEndpointSuffix `
                              -vmAdminUserName $UserName -vmAdminPassword $Password `
                              -verbose

                              