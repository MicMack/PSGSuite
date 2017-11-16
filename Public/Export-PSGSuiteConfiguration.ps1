function Export-PSGSuiteConfiguration {
    [cmdletbinding()]
    Param
    (
        [parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [ValidateScript({
            if ($_ -eq "DefaultConfig") {
                throw "You must specify a ConfigName other than 'DefaultConfig'. That is a reserved value."
            }
            elseif ($_ -notmatch '^[a-zA-Z]+[a-zA-Z0-9]*$') {
                throw "You must specify a ConfigName that starts with a letter and does not contain any spaces, otherwise the Configuration will break"
            }
            else {
                $true
            }
        })]
        [string]
        $ConfigName,
        [parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
        [switch]
        $SetAsDefaultConfig,
        [parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
        [string]
        $Domain,
        [parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
        [string]
        $P12KeyPath,
        [parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
        [string]
        $AppEmail,
        [parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
        [string]
        $AdminEmail,
        [parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
        [string]
        $CustomerID,
        [parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
        [ValidateSet("Domain","CustomerID")]
        [string]
        $Preference="CustomerID",
        [parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true)]
        [string]
        $ServiceAccountClientID,
        [parameter(Mandatory=$false)]
        [ValidateSet("User", "Machine", "Enterprise")]
        [string]
        $Scope = "Enterprise"
    )
    Begin {
        Write-Verbose "PSBoundParameters on Export-PSGSuiteConfiguration:`n$($PSBoundParameters | Out-String)"
        $configHash = Import-Configuration -CompanyName "SCRT HQ" -Name "PSGSuite"
        $configParams = @("P12KeyPath","AppEmail","AdminEmail","CustomerId","Domain","Preference","ServiceAccountClientID")
        if ($SetAsDefaultConfig) {
            $configHash["DefaultConfig"] = $ConfigName
        }
        if (!$configHash[$ConfigName]) {
            $configHash.Add($ConfigName,(@{}))
        }
        foreach ($key in ($PSBoundParameters.Keys | Where-Object {$configParams -contains $_})) {
            $configHash["$ConfigName"][$key] = $PSBoundParameters[$key]
        }
    }
    Process {
        if (Get-Module Configuration -ListAvailable) {
            $Ver = @{}
            if ($PSBoundParameters.Keys -Contains "Verbose") {
                $Ver.Add("Verbose",$Verbose)
            }
            $configHash | Export-Configuration -Scope $Scope -CompanyName "SCRT HQ" -Name "PSGSuite" @Ver
        }
        else {
            Write-Warning "Configuration module not found! Please run 'Install-Module Configuration' to install from PSGallery"
        }
    }
}