Param
(
    [parameter(Position = 0)]
    $UseConfiguration = $false,
    [parameter(Position = 1)]
    $ForceDotSource = $false
)
if ($IsCoreCLR) {
    Write-Warning "This module is not supported on CoreCLR yet!"
    throw "Skipping module import - unsupported CLR"
}
#Get public and private function definition files.
$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )
$ModuleRoot = $PSScriptRoot

#Execute a scriptblock to load each function instead of dot sourcing (Issue #5)
foreach ($file in @($Public + $Private)) {
    if ($ForceDotSource) {
        . $file.FullName
    }
    else {
        $ExecutionContext.InvokeCommand.InvokeScript(
            $false, 
            (
                [scriptblock]::Create(
                    [io.file]::ReadAllText(
                        $file.FullName,
                        [Text.Encoding]::UTF8
                    )
                )
            ), 
            $null, 
            $null
        )
    }
}
if ((Get-Module Configuration -ListAvailable) -and (Test-Path "$ModuleRoot\Configuration.psd1") -and $UseConfiguration) {
    Write-Host "Importing Configuration.psd1"
    Add-MetadataConverter -Converters @{
        [PSCredential] = {
            $encParams = @{}
            if ($script:EncryptionMethod -ne "DPAPI" -and $script:EncryptionKey -is [System.Byte[]]) {
                $encParams[$script:EncryptionMethod] = $script:EncryptionKey
                'PSCredential "{0}" (ConvertTo-SecureString "{1}" -Key (Get-Key))' -f $_.UserName, (ConvertFrom-SecureString $_.Password @encParams)
            }
            else {
    
                'PSCredential "{0}" "{1}"' -f $_.UserName, (ConvertFrom-SecureString $_.Password)
            }
        }
        "PSCredential" = {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword","EncodedPassword")]
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingUserNameAndPasswordParams","")]
            param(
                [string]$UserName,
                [string]$EncodedPassword
            )
            $encParams = @{}
            if ($script:EncryptionMethod -ne "DPAPI" -and $script:EncryptionKey -is [System.Byte[]]) {
                $encParams[$script:EncryptionMethod] = $script:EncryptionKey
            }
            New-Object PSCredential $UserName, (ConvertTo-SecureString $EncodedPassword @encParams)
        }
        [SecureString] = {
            $encParams = @{}
            if ($script:EncryptionMethod -ne "DPAPI" -and $script:EncryptionKey -is [System.Byte[]]) {
                $encParams[$script:EncryptionMethod] = $script:EncryptionKey
            }
            'Secure "{0}"' -f (ConvertFrom-SecureString $_ @encParams)
        }
        "Secure" = {
            param([string]$String)
            $encParams = @{}
            if ($script:EncryptionMethod -ne "DPAPI" -and $script:EncryptionKey -is [System.Byte[]]) {
                $encParams[$script:EncryptionMethod] = $script:EncryptionKey
            }
            ConvertTo-SecureString $String @encParams
        }
    }
    #$null = ImportConfiguration
    Import-PSGSuiteConfiguration
}
else {
    #Initialize the config variable
    Try {
        #Import the config
        $script:PSGSuite = $null
        $script:PSGSuite = Get-PSGSuiteConfig -Source "PSGSuite.xml" -ErrorAction Stop
    }
    Catch {   
        Write-Warning "Error importing PSGSuite config: $_"
    }
}
Export-ModuleMember -Function $Public.Basename