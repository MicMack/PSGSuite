function Remove-GSOrganizationalUnit {
    <#
    .Synopsis
       Removes an existing Google Organizational Unit
    .DESCRIPTION
       Removes an existing Google Organizational Unit
    .EXAMPLE
       Remove-GSUser -OrgUnitPath john.smith@domain.com -WhatIf
    .EXAMPLE
       Remove-GSUser -User john.smith@domain.com -Confirm:$false
    #>
    [cmdletbinding(SupportsShouldProcess = $true,ConfirmImpact = "High")]
    Param
    (
        [parameter(Mandatory = $true,Position = 0)]
        [String]
        $OrgUnitPath,
        [parameter(Mandatory = $false)]
        [String]
        $AccessToken,
        [parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [String]
        $CustomerID=$Script:PSGSuite.CustomerID,
        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String]
        $P12KeyPath = $Script:PSGSuite.P12KeyPath,
        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String]
        $AppEmail = $Script:PSGSuite.AppEmail,
        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String]
        $AdminEmail = $Script:PSGSuite.AdminEmail
    )
    if (!$AccessToken) {
        $AccessToken = Get-GSToken -P12KeyPath $P12KeyPath -Scopes "https://www.googleapis.com/auth/admin.directory.orgunit" -AppEmail $AppEmail -AdminEmail $AdminEmail
    }
    $header = @{
        Authorization = "Bearer $AccessToken"
    }
    $URI = "https://www.googleapis.com/admin/directory/v1/customer/$($CustomerID)/orgunits/$($OrgUnitPath)"
    if ($PSCmdlet.ShouldProcess($OrgUnitPath)) {
        try {
            $response = Invoke-RestMethod -Method Delete -Uri $URI -Headers $header -ContentType "application/json"
            if (!$response) {
                Write-Host "OrgUnitPath $OrgUnitPath successfully removed from the domain"
            }
        }
        catch {
            try {
                $result = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($result)
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $resp = $reader.ReadToEnd()
                $response = $resp | ConvertFrom-Json | 
                    Select-Object @{N = "Error";E = {$Error[0]}},@{N = "Code";E = {$_.error.Code}},@{N = "Message";E = {$_.error.Message}},@{N = "Domain";E = {$_.error.errors.domain}},@{N = "Reason";E = {$_.error.errors.reason}}
                Write-Error "$(Get-HTTPStatus -Code $response.Code): $($response.Domain) / $($response.Message) / $($response.Reason)"
                return
            }
            catch {
                Write-Error $resp
                return
            }
        }
    }
    return $response
}