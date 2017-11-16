function Import-PSGSuiteConfiguration {
    [cmdletbinding()]
    Param
    (
        [parameter(Mandatory=$false,Position=0)]
        [String]
        $Config = "Default"
    )
    if (Get-Module Configuration -ListAvailable) {
        $fullConf = Import-Configuration -CompanyName "SCRT HQ" -Name "PSGSuite"
        if ($Config -eq "Default") {
            $defConfigName = $fullConf["DefaultConfig"]
            Write-Verbose "Importing default config: $defConfigName"
            $script:PSGSuite = [PSCustomObject]($fullConf[$defConfigName])
            Write-Verbose "`n`n`tImported config: $defConfigName`n`tAdmin Email: $($script:PSGSuite.AdminEmail)`n`tDomain: $($script:PSGSuite.Domain)"
        }
        else {
            Write-Verbose "Importing config: $Config"
            $script:PSGSuite = [PSCustomObject]($fullConf[$Config])
            Write-Verbose "`n`n`tImported config: $Config`n`tAdmin Email: $($script:PSGSuite.AdminEmail)`n`tDomain: $($script:PSGSuite.Domain)"
        }
    }
    else {
        Write-Warning "Configuration module not found! Please run 'Install-Module Configuration' to install from PSGallery"
    }
}