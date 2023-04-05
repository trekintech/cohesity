Function Get-ObjectName{
    Param(        
        $ApiKey,
        $ObjectId,
        $RegionId
    )
    Begin{ 
        $URI = 'https://helios.cohesity.com/v2/data-protect/objects'
    }
    Process{
        $Headers = @{
            'apiKey'   = $apiKey
            'Accept'   = 'application/json'
            'regionId' = $regionId
        }
        $Body = @{
            'ids' = $objectId
            'onlyProtectedObjects' = $true
        }

        Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers -Body $Body | 
            Select-Object -ExpandProperty objects | 
            Select-Object -ExpandProperty name
    }
}

Function Get-AuditLogs{
    Param(
        $ApiKey
    )
    Begin{
        $startTime = [datetime]::UtcNow.AddDays(-1)
        $startTimeUsecs = [math]::Round((($startTime.ToUniversalTime() - [datetime]'1/1/1970 00:00:00').TotalMilliseconds * 1000), 0)
        
        $Uri = 'https://helios.cohesity.com/v2/mcm/audit-logs'
    }
    Process{
        $Headers = @{
            'apiKey' = $ApiKey
            'Accept' = 'application/json'
        }
        $Body = @{
            'includeDmaasLogs' = 'true'
            'serviceContext' = 'Dmaas'
            'startTimeUsecs' = [int64]$startTimeUsecs
        }

        Invoke-RestMethod -Method GET -Uri $Uri -Headers $Headers -Body $Body
    }
}

<#
$RegionId = 'EnterRegion'
$ApiKey   = 'EnterAPIKey'
$Response = Get-AuditLogs

#$backup = Get-AuditLogs
#$Response = $backup
#>

Function Update-AuditLogs{
    Param(
        $RegionId = 'EnterRegion',
        $ApiKey   = 'EnterAPI'
    )
    Process{
        $Response = Get-AuditLogs -ApiKey $ApiKey

        Foreach($Log in $($Response.auditLogs)){
            #Processing RecoveryTask    
            If ($Log.entityType -eq 'RecoveryTask'){
                $Record = $($Log.newRecord) | ConvertFrom-Json        
                $ObjId = $($Record.office365Params.recoverMailboxParams.targetMailbox.id)        
                If ($ObjectId){
                    $ObjName = Get-ObjectName -ApiKey $ApiKey -ObjectId $ObjId -RegionId $RegionId
                    If ($Record.office365Params.recoverMailboxParams.targetMailbox.PSObject.Properties.Name -contains "name") {
                        $Record.office365Params.recoverMailboxParams.targetMailbox.name = $ObjName
                    }
                    Else {
                    $Record.office365Params.recoverMailboxParams.targetMailbox | 
                        Add-Member -MemberType NoteProperty -Name name -Value $ObjName
                    }
                    $OutResult = ($Record | ConvertTo-Json -Depth 12)
                    $Log.newRecord = $OutResult.toString()
                }
                $Log
            }
            #Non Recovery Task - Comment out the below line if only recoveries are required
            Else{ $Log }
        }
    }
}

Update-AuditLogs -RegionId 'EnterRegion' -ApiKey 'EnterAPIKey'
