function Import-GSSheet {
    [cmdletbinding(DefaultParameterSetName="SheetsAPI")]
    Param
    (      
      [parameter(Mandatory=$true)]
      [String]
      $SpreadsheetId,
      [parameter(Mandatory=$false)]
      [String]
      $SheetName,
      [parameter(Mandatory=$false)]
      [ValidateNotNullOrEmpty()]
      [String]
      $Owner = $Script:PSGSuite.AdminEmail,
      [parameter(ParameterSetName="DriveAPI",Mandatory=$false)]
      [switch]
      $UseDriveAPI,
      [parameter(ParameterSetName="SheetsAPI",Mandatory=$false)]
      [ValidateNotNullOrEmpty()]
      [string]
      $SpecifyRange="A1:Z1000",
      [parameter(ParameterSetName="SheetsAPI",Mandatory=$false)]
      [ValidateSet("FORMATTED_STRING","SERIAL_NUMBER")]
      [string]
      $DateTimeRenderOption="FORMATTED_STRING",
      [parameter(ParameterSetName="SheetsAPI",Mandatory=$false)]
      [ValidateSet("FORMATTED_VALUE","UNFORMATTED_VALUE","FORMULA")]
      [string]
      $ValueRenderOption="FORMATTED_VALUE",
      [parameter(ParameterSetName="SheetsAPI",Mandatory=$false)]
      [ValidateSet("ROWS","COLUMNS","DIMENSION_UNSPECIFIED")]
      [string]
      $MajorDimension="ROWS",
      [parameter(ParameterSetName="SheetsAPI",Mandatory=$false)]
      [int]
      $RowStart=1,
      [parameter(ParameterSetName="SheetsAPI",Mandatory=$false)]
      [string[]]
      $Headers,
      [parameter(ParameterSetName="SheetsAPI",Mandatory=$false)]
      [switch]
      $Raw,
      [parameter(Mandatory=$false)]
      [String]
      $AccessToken,
      [parameter(Mandatory=$false)]
      [ValidateNotNullOrEmpty()]
      [String]
      $P12KeyPath = $Script:PSGSuite.P12KeyPath,
      [parameter(Mandatory=$false)]
      [ValidateNotNullOrEmpty()]
      [String]
      $AppEmail = $Script:PSGSuite.AppEmail,
      [parameter(Mandatory=$false)]
      [ValidateNotNullOrEmpty()]
      [String]
      $AdminEmail = $Script:PSGSuite.AdminEmail
    )
if ($UseDriveAPI)
    {
    $TempCSV = "$env:TEMP\PSGoogle-TempCSV-$((New-Guid).Guid).csv"
    $fileParams = @{
        FileID=$SpreadsheetId
        Owner=$Owner
        Type="CSV"
        OutFilePath=$TempCSV 
        }
    if ($AccessToken)
        {
        $fileParams.Add("AccessToken",$AccessToken)
        }
    else 
        {
        $fileParams.Add("P12KeyPath",$P12KeyPath)
        $fileParams.Add("AppEmail",$AppEmail)
        $fileParams.Add("AdminEmail",$AdminEmail)
        }
    Write-Verbose "Downloading temp CSV to: $TempCSV"
    Get-GSDriveFile @fileParams -Verbose:$false
    Write-Verbose "Importing temp CSV"
    $response = Import-Csv $TempCSV
    Write-Verbose "Removing temp CSV"
    Remove-Item $TempCSV -Force
    }
else
    {
    if ($MajorDimension -ne "ROWS" -and !$Raw)
        {
        $Raw = $true
        Write-Warning "Setting -Raw to True -- Parsing requires the MajorDimension to be set to ROWS (default value)"
        }
    if (!$AccessToken)
        {
        Write-Verbose "Acquiring token"
        $AccessToken = Get-GSToken -P12KeyPath $P12KeyPath -Scopes "https://www.googleapis.com/auth/drive" -AppEmail $AppEmail -AdminEmail $Owner -Verbose:$false
        if ($AccessToken)
            {
            Write-Verbose "Token acquired!"
            }
        else
            {
            Write-Error $Error[0]
            return
            }
        }
    $header = @{
        Authorization="Bearer $AccessToken"
        }
    if ($SheetName)
        {
        if ($SpecifyRange -like "'*'!*")
            {
            Write-Error "SpecifyRange formatting error! When using the SheetName parameter, please exclude the SheetName when formatting the SpecifyRange value (i.e. 'A1:Z1000')"
            return
            }
        elseif ($SpecifyRange)
            {
            $SpecifyRange = "'$($SheetName)'!$SpecifyRange"
            }
        else
            {
            $SpecifyRange = "$SheetName"
            }
        }
    $URI = "https://sheets.googleapis.com/v4/spreadsheets/$SpreadsheetId/values:batchGet?ranges=$SpecifyRange&dateTimeRenderOption=$DateTimeRenderOption&majorDimension=$MajorDimension&valueRenderOption=$ValueRenderOption"
    try
        {
        $response = Invoke-RestMethod -Method Get -Uri $URI -Headers $header -ContentType "application/json" | ForEach-Object {if($_.kind -like "*#*"){$_.PSObject.TypeNames.Insert(0,$(Convert-KindToType -Kind $_.kind));$_}else{$_}}
        if (!$Raw)
            {
            $i=0
            $datatable = New-Object System.Data.Datatable
            if ($Headers)
                {
                foreach ($col in $Headers)
                    {
                    [void]$datatable.Columns.Add("$col")
                    }
                $i++
                }
            $(if ($RowStart){$response.valueRanges.values | Select-Object -Skip $([int]$RowStart -1)}else{$response.valueRanges.values}) | % {
                if ($i -eq 0)
                    {
                    foreach ($col in $_)
                        {
                        [void]$datatable.Columns.Add("$col")
                        }
                    }
                else
                    {
                    [void]$datatable.Rows.Add($_)
                    }
                $i++
                }
            }
        Write-Verbose "Created DataTable object with $($i - 1) Rows"
        return $datatable
        }
    catch
        {
        try
            {
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $resp = $reader.ReadToEnd()
            $response = $resp | ConvertFrom-Json | 
                Select-Object @{N="Error";E={$Error[0]}},@{N="Code";E={$_.error.Code}},@{N="Message";E={$_.error.Message}},@{N="Domain";E={$_.error.errors.domain}},@{N="Reason";E={$_.error.errors.reason}}
            }
        catch
            {
            $response = $resp
            }
        }
    }
return $response
}