function New-DbaAvailabilityGroup {
    <#
    .SYNOPSIS
        Automates the creation of availability groups.

    .DESCRIPTION
        Automates the creation of availability groups.

        * Checks prerequisites
        * Creates Availability Group and adds primary replica
        * Grants cluster permissions if necessary
        * Adds secondary replica if supplied
        * Adds databases if supplied
            * Performs backup/restore if seeding mode is manual
            * Performs backup to NUL if seeding mode is automatic
        * Adds listener to primary if supplied
        * Joins secondaries to availability group
        * Grants endpoint connect permissions to service accounts
        * Grants CreateAnyDatabase permissions if seeding mode is automatic
        * Returns Availability Group object from primary

        NOTE: If a backup / restore is performed, the backups will be left intact on the network share.

        Thanks for this, Thomas Stringer! https://blogs.technet.microsoft.com/heyscriptingguy/2013/04/29/set-up-an-alwayson-availability-group-with-powershell/

    .PARAMETER Primary
        The primary SQL Server instance. Server version must be SQL Server version 2012 or higher.

    .PARAMETER PrimarySqlCredential
        Login to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance.

    .PARAMETER Secondary
        The target SQL Server instance or instances. Server version must be SQL Server version 2012 or higher.

    .PARAMETER SecondarySqlCredential
        Login to the target instance using alternative credentials. Accepts PowerShell credentials (Get-Credential).

        Windows Authentication, SQL Server Authentication, Active Directory - Password, and Active Directory - Integrated are all supported.

        For MFA support, please use Connect-DbaInstance.

    .PARAMETER Name
        The name of the Availability Group.

    .PARAMETER DtcSupport
        Indicates whether the DtcSupport is enabled

    .PARAMETER ClusterType
        Cluster type of the Availability Group. Only supported in SQL Server 2017 and above.
        Options include: External, Wsfc or None. None by default.

    .PARAMETER AutomatedBackupPreference
        Specifies how replicas in the primary role are treated in the evaluation to pick the desired replica to perform a backup.

    .PARAMETER FailureConditionLevel
        Specifies the different conditions that can trigger an automatic failover in Availability Group.

    .PARAMETER HealthCheckTimeout
        This setting used to specify the length of time, in milliseconds, that the SQL Server resource DLL should wait for information returned by the sp_server_diagnostics stored procedure before reporting the Always On Failover Cluster Instance (FCI) as unresponsive.

        Changes that are made to the timeout settings are effective immediately and do not require a restart of the SQL Server resource.

        Defaults to 30000 (30 seconds).

    .PARAMETER Basic
        Indicates whether the availability group is basic. Basic availability groups like pumpkin spice and uggs.

        https://docs.microsoft.com/en-us/sql/database-engine/availability-groups/windows/basic-availability-groups-always-on-availability-groups

    .PARAMETER DatabaseHealthTrigger
        Indicates whether the availability group triggers the database health.

    .PARAMETER Passthru
        Don't create the availability group, just pass thru an object that can be further customized before creation.

    .PARAMETER Database
        The database or databases to add.

    .PARAMETER SharedPath
        The network share where the backups will be backed up and restored from.

        Each SQL Server service account must have access to this share.

        NOTE: If a backup / restore is performed, the backups will be left in tact on the network share.

    .PARAMETER UseLastBackup
        Use the last full backup of database.

    .PARAMETER Force
        Drop and recreate the database on remote servers using fresh backup.

    .PARAMETER AvailabilityMode
        Sets the availability mode of the availability group replica. Options are: AsynchronousCommit and SynchronousCommit. SynchronousCommit is default.

    .PARAMETER FailoverMode
        Sets the failover mode of the availability group replica. Options are Automatic, Manual and External. Automatic is default.

    .PARAMETER BackupPriority
        Sets the backup priority availability group replica. Default is 50.

    .PARAMETER Endpoint
        By default, this command will attempt to find a DatabaseMirror endpoint. If one does not exist, it will create it.

        If an endpoint must be created, the name "hadr_endpoint" will be used. If an alternative is preferred, use Endpoint.

    .PARAMETER ConnectionModeInPrimaryRole
        Specifies the connection intent modes of an Availability Replica in primary role. AllowAllConnections by default.

    .PARAMETER ConnectionModeInSecondaryRole
        Specifies the connection modes of an Availability Replica in secondary role. AllowAllConnections by default.

    .PARAMETER ReadonlyRoutingConnectionUrl
        Sets the read only routing connection url for the availability replica.

    .PARAMETER SeedingMode
        Specifies how the secondary replica will be initially seeded.

        Automatic enables direct seeding. This method will seed the secondary replica over the network. This method does not require you to backup and restore a copy of the primary database on the replica.

        Manual requires you to create a backup of the database on the primary replica and manually restore that backup on the secondary replica.

    .PARAMETER Certificate
        Specifies that the endpoint is to authenticate the connection using the certificate specified by certificate_name to establish identity for authorization.

        The far endpoint must have a certificate with the public key matching the private key of the specified certificate.

    .PARAMETER ListenerName
        Sets listener name for primary AG.

    .PARAMETER DagListenerName
        Sets listener name for the Distributed AG.

    .PARAMETER IPAddress
        Sets the IP address of the availability group listener.

    .PARAMETER SubnetMask
        Sets the subnet IP mask of the availability group listener.

    .PARAMETER Port
        Sets the number of the port used to communicate with the availability group.

    .PARAMETER Dhcp
        Indicates whether the object is DHCP.

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER Confirm
        Prompts you for confirmation before executing any changing operations within the command.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: AvailabilityGroup, HA, AG
        Author: Chrissy LeMaire (@cl), netnerds.net

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/New-DbaAvailabilityGroup

    .EXAMPLE
        PS C:\> New-DbaAvailabilityGroup -Primary sql2016a -Name SharePoint

        Creates a new availability group on sql2016a named SharePoint

    .EXAMPLE
        PS C:\> New-DbaAvailabilityGroup -Primary sql2016a -Name SharePoint -Secondary sql2016b

        Creates a new availability group on sql2016a named SharePoint with a secondary replica, sql2016b

    .EXAMPLE
        PS C:\> New-DbaAvailabilityGroup -Primary sql2016std -Name BAG1 -Basic -Confirm:$false

        Creates a basic availability group named BAG1 on sql2016std and does not confirm when setting up

    .EXAMPLE
        PS C:\> New-DbaAvailabilityGroup -Primary sql2016b -Name AG1 -ClusterType Wsfc -Dhcp -Database db1 -UseLastBackup

        Creates an availability group on sql2016b with the name ag1. Uses the last backups available to add the database db1 to the AG.

    .EXAMPLE
        PS C:\> New-DbaAvailabilityGroup -Primary sql2017 -Name SharePoint -ClusterType None -FailoverMode Manual

        Creates a new availability group on sql2017 named SharePoint with a cluster type of none and a failover mode of manual

    .EXAMPLE
        PS C:\> New-DbaAvailabilityGroup -Primary sql1 -Secondary sql2 -Name ag1 -Database pubs -ClusterType None -SeedingMode Automatic -FailoverMode Manual

        Creates a new availability group with a primary replica on sql1 and a secondary on sql2. Automatically adds the database pubs.

    .EXAMPLE
        PS C:\> New-DbaAvailabilityGroup -Primary sql1 -Secondary sql2 -Name ag1 -Database pubs -ClusterType wsfc -SeedingMode Automatic -FailoverMode Manual

        PS C:\> New-DbaAvailabilityGroup -Primary sql3 -Secondary sql4 -Name ag2 -ClusterType wsfc -Dhcp -SeedingMode Automatic -FailoverMode Manual

        PS C:\> New-DbaAvailabilityGroup -Primary sql3 -Secondary -sql4 -Listener1 ag1 -Listener2 ag2 -Name dag -Database pubs -Distributed -SeedingMode Automatic -FailoverMode Manual

        Creates a new distributed availability group.

    .EXAMPLE
        PS C:\> $cred = Get-Credential sqladmin
        PS C:\> $params = @{
        >> Primary = "sql1"
        >> PrimarySqlCredential = $cred
        >> Secondary = "sql2"
        >> SecondarySqlCredential = $cred
        >> Name = "test-ag"
        >> Database = "pubs"
        >> ClusterType = "None"
        >> SeedingMode = "Automatic"
        >> FailoverMode = "Manual"
        >> Confirm = $false
        >> }
        PS C:\> New-DbaAvailabilityGroup @params

        This exact command was used to create an availability group on docker!
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [parameter(ValueFromPipeline)]
        [DbaInstanceParameter]$Primary,
        [PSCredential]$PrimarySqlCredential,
        [DbaInstanceParameter[]]$Secondary,
        [PSCredential]$SecondarySqlCredential,
        # AG

        [parameter(Mandatory)]
        [string]$Name,
        [switch]$DtcSupport,
        [ValidateSet('External', 'Wsfc', 'None')]
        [string]$ClusterType = 'External',
        [ValidateSet('None', 'Primary', 'Secondary', 'SecondaryOnly')]
        [string]$AutomatedBackupPreference = 'Secondary',
        [ValidateSet('OnAnyQualifiedFailureCondition', 'OnCriticalServerErrors', 'OnModerateServerErrors', 'OnServerDown', 'OnServerUnresponsive')]
        [string]$FailureConditionLevel = "OnServerDown",
        [int]$HealthCheckTimeout = 30000,
        [switch]$Basic,
        [switch]$DatabaseHealthTrigger,
        [switch]$Passthru,
        # database

        [string[]]$Database,
        [string]$SharedPath,
        [switch]$UseLastBackup,
        [switch]$Force,
        # replica

        [ValidateSet('AsynchronousCommit', 'SynchronousCommit')]
        [string]$AvailabilityMode = "SynchronousCommit",
        [ValidateSet('Automatic', 'Manual', 'External')]
        [string]$FailoverMode = "Automatic",
        [int]$BackupPriority = 50,
        [ValidateSet('AllowAllConnections', 'AllowReadWriteConnections')]
        [string]$ConnectionModeInPrimaryRole = 'AllowAllConnections',
        [ValidateSet('AllowAllConnections', 'AllowNoConnections', 'AllowReadIntentConnectionsOnly', 'No', 'Read-intent only', 'Yes')]
        [string]$ConnectionModeInSecondaryRole = 'AllowAllConnections',
        [ValidateSet('Automatic', 'Manual')]
        [string]$SeedingMode = 'Manual',
        [string]$Endpoint,
        [string]$ReadonlyRoutingConnectionUrl,
        [string]$Certificate,
        # network

        [string]$ListenerName,
        [string]$DagListnerName,
        [ipaddress[]]$IPAddress,
        [ipaddress]$SubnetMask = "255.255.255.0",
        [int]$Port = 1433,
        [switch]$Dhcp,

        #Distibuted AGs
        [switch]$Distributed,
        [switch]$EnableException
    )
    begin {
        if ($Force) { $ConfirmPreference = 'none' }
    }
    process {
        $stepCounter = $wait = 0

        if ($Force -and $Secondary -and (-not $SharedPath -and -not $UseLastBackup) -and ($SeedingMode -ne 'Automatic')) {
            Stop-Function -Message "SharedPath or UseLastBackup is required when Force is used"
            return
        }

        if ($ConnectionModeInSecondaryRole) {
            $ConnectionModeInSecondaryRole =
            switch ($ConnectionModeInSecondaryRole) {
                "No" { "AllowNoConnections" }
                "Read-intent only" { "AllowReadIntentConnectionsOnly" }
                "Yes" { "AllowAllConnections" }
                default { $ConnectionModeInSecondaryRole }
            }
        }

        try {
            $server = Connect-SqlInstance -SqlInstance $Primary -SqlCredential $PrimarySqlCredential
        } catch {
            Stop-Function -Message "Error occurred while establishing connection to $Primary" -Category ConnectionError -ErrorRecord $_ -Target $Primary
            return
        }

        if ($SeedingMode -eq 'Automatic' -and $server.VersionMajor -lt 13) {
            Stop-Function -Message "Automatic seeding mode only supported in SQL Server 2016 and above" -Target $Primary
            return
        }

        if ($Basic -and $server.VersionMajor -lt 13) {
            Stop-Function -Message "Basic availability groups are only supported in SQL Server 2016 and above" -Target $Primary
            return
        }

        if ($Distributed -and $server.VersionMajor -lt 13) {
            Stop-Function -Message "Distributed availability groups are only supported in SQL Server 2016 and above" -Target $Primary
            return
        }

        Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Checking perquisites"

        # Don't reuse $server here, it fails
        if (Get-DbaAvailabilityGroup -SqlInstance $Primary -SqlCredential $PrimarySqlCredential -AvailabilityGroup $Name) {
            if (-not $Distributed) {
                Stop-Function -Message "Availability group named $Name already exists on $Primary"
            } else {
                Stop-Function -Message "Distributed availability group named $Name already exists on $Primary"
            }
            return
        }

        if ($Certificate) {
            $cert = Get-DbaDbCertificate -SqlInstance $Primary -SqlCredential $PrimarySqlCredential -Certificate $Certificate
            if (-not $cert) {
                Stop-Function -Message "Certificate $Certificate does not exist on $Primary" -ErrorRecord $_ -Target $Primary
                return
            }
        }

        if (($SharedPath)) {
            if (-not (Test-DbaPath -SqlInstance $Primary -SqlCredential $PrimarySqlCredential -Path $SharedPath)) {
                Stop-Function -Continue -Message "Cannot access $SharedPath from $Primary"
                return
            }
        }

        if ($Database -and -not $UseLastBackup -and -not $SharedPath -and ($Secondary -or $Distributed) -and $SeedingMode -ne 'Automatic') {
            if (-not $Distributed) {
                Stop-Function -Continue -Message "You must specify a SharedPath when adding databases to a manually seeded availability group"
            } else {
                Stop-Function -Continue -Message "You must specify a SharedPath when adding databases to a manually seeded distributed availability group"
            }
            return
        }

        if (-not $Distributed -and $null -eq $ListenerName) {
            Stop-Function -Continue -Message "You must specify a name for the listener for the you AG."
            return
        } elseif ($Distributed -and $null -eq $DagListenerName) {
            Stop-Function -Continue -Message "You must specify a specficy a name for the Distributed AG Listener "
            return
        }

        if ($server.HostPlatform -eq "Linux") {
            # New to SQL Server 2017 (14.x) is the introduction of a cluster type for AGs. For Linux, there are two valid values: External and None.
            if ($ClusterType -notin "External", "None") {
                Stop-Function -Continue -Message "Linux only supports ClusterType of External or None"
                return
            }
            # Microsoft Distributed Transaction Coordinator (DTC) is not supported under Linux in SQL Server 2017
            if ($DtcSupport) {
                Stop-Function -Continue -Message "Microsoft Distributed Transaction Coordinator (DTC) is not supported under Linux"
                return
            }
        }

        if ($ClusterType -eq "None" -and $server.VersionMajor -lt 14) {
            Stop-Function -Message "ClusterType of None only supported in SQL Server 2017 and above"
            return
        }

        if ($Secondary) {
            $secondaries = @()
            foreach ($computer in $Secondary) {
                try {
                    $secondaries += Connect-SqlInstance -SqlInstance $computer -SqlCredential $SecondarySqlCredential
                } catch {
                    Stop-Function -Message "Error occurred while establishing connection to $instance" -Category ConnectionError -ErrorRecord $_ -Target $Primary
                    return
                }
            }

            if ($SeedingMode -eq "Automatic") {
                $primarypath = Get-DbaDefaultPath -SqlInstance $server
                foreach ($second in $secondaries) {
                    $secondarypath = Get-DbaDefaultPath -SqlInstance $second
                    if ($primarypath.Data -ne $secondarypath.Data) {
                        Write-Message -Level Warning -Message "Primary and secondary ($second) default data paths do not match. Trying anyway."
                    }
                    if ($primarypath.Log -ne $secondarypath.Log) {
                        Write-Message -Level Warning -Message "Primary and secondary ($second) default log paths do not match. Trying anyway."
                    }
                }
            }
        }

        # database checks
        if ($Database) {
            if (-not $Distributed) {
                $dbs += Get-DbaDatabase -SqlInstance $Primary -SqlCredential $PrimarySqlCredential -Database $Database
            }
        }

        foreach ($primarydb in $dbs) {
            if ($primarydb.MirroringStatus -ne "None") {
                Stop-Function -Message "Cannot setup mirroring on database ($dbname) due to its current mirroring state: $($primarydb.MirroringStatus)"
                return
            }

            if ($primarydb.Status -ne "Normal") {
                Stop-Function -Message "Cannot setup mirroring on database ($dbname) due to its current state: $($primarydb.Status)"
                return
            }

            if ($primarydb.RecoveryModel -ne "Full") {
                if ((Test-Bound -ParameterName UseLastBackup)) {
                    Stop-Function -Message "$dbName not set to full recovery. UseLastBackup cannot be used."
                    return
                } else {
                    Set-DbaDbRecoveryModel -SqlInstance $Primary -SqlCredential $PrimarySqlCredential -Database $primarydb.Name -RecoveryModel Full
                }
            }
        }

        if (-not $Distributed) {
            Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Creating availability group named $Name on $Primary"
        } else {
            Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Creating distributed availability group named $Name on $Primary"
        }

        # Start work
        if (-not $Distributed) {
            $progress = "Setting up availability group named $Name and adding primary replica"
        } else {
            $progress = "Setting up distributed availability group named $Name and adding primary forwarder"
        }

        if ($Pscmdlet.ShouldProcess($Primary, $progress)) {
            try {
                $ag = New-Object Microsoft.SqlServer.Management.Smo.AvailabilityGroup -ArgumentList $server, $Name
                $ag.AutomatedBackupPreference = [Microsoft.SqlServer.Management.Smo.AvailabilityGroupAutomatedBackupPreference]::$AutomatedBackupPreference
                $ag.FailureConditionLevel = [Microsoft.SqlServer.Management.Smo.AvailabilityGroupFailureConditionLevel]::$FailureConditionLevel
                $ag.HealthCheckTimeout = $HealthCheckTimeout

                if ($server.VersionMajor -ge 13) {
                    $ag.BasicAvailabilityGroup = $Basic
                    $ag.DatabaseHealthTrigger = $DatabaseHealthTrigger
                    $ag.DtcSupportEnabled = $DtcSupport
                    $ag.IsDistributedAvailabilityGroup = $Distributed
                }

                if ($server.VersionMajor -ge 14) {
                    $ag.ClusterType = $ClusterType
                }

                if ($PassThru) {
                    $defaults = 'LocalReplicaRole', 'Name as AvailabilityGroup', 'PrimaryReplicaServerName as PrimaryReplica', 'AutomatedBackupPreference', 'AvailabilityReplicas', 'AvailabilityDatabases', 'AvailabilityGroupListeners'
                    return (Select-DefaultView -InputObject $ag -Property $defaults)
                }

                $replicaparams = @{
                    InputObject                   = $ag
                    AvailabilityMode              = $AvailabilityMode
                    FailoverMode                  = $FailoverMode
                    BackupPriority                = $BackupPriority
                    ConnectionModeInPrimaryRole   = $ConnectionModeInPrimaryRole
                    ConnectionModeInSecondaryRole = $ConnectionModeInSecondaryRole
                    Endpoint                      = $Endpoint
                    ReadonlyRoutingConnectionUrl  = $ReadonlyRoutingConnectionUrl
                    Certificate                   = $Certificate
                }

                if ($server.VersionMajor -ge 13) {
                    $replicaparams += @{SeedingMode = $SeedingMode }
                }

                $null = Add-DbaAgReplica @replicaparams -EnableException -SqlInstance $server
            } catch {
                $msg = $_.Exception.InnerException.InnerException.Message
                if (-not $msg) {
                    $msg = $_
                }
                Stop-Function -Message $msg -ErrorRecord $_ -Target $Primary
                return
            }
        }

        # Add cluster permissions
        if ($ClusterType -eq 'Wsfc') {
            Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Adding endpoint connect permissions"

            foreach ($second in $secondaries) {
                if ($Pscmdlet.ShouldProcess($Primary, "Adding cluster permissions for availability group named $Name")) {
                    Write-Message -Level Verbose -Message "WSFC Cluster requires granting [NT AUTHORITY\SYSTEM] a few things. Setting now."
                    $sql = "GRANT ALTER ANY AVAILABILITY GROUP TO [NT AUTHORITY\SYSTEM]
                        GRANT CONNECT SQL TO [NT AUTHORITY\SYSTEM]
                        GRANT VIEW SERVER STATE TO [NT AUTHORITY\SYSTEM]"
                    try {
                        $null = $server.Query($sql)
                        foreach ($second in $secondaries) {
                            $null = $second.Query($sql)
                        }
                    } catch {
                        Stop-Function -Message "Failure adding cluster service account permissions" -ErrorRecord $_
                    }
                }
            }
        }

        # Add replicas
        Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Adding secondary replicas"

        foreach ($second in $secondaries) {
            if ($Pscmdlet.ShouldProcess($second.Name, "Adding replica to availability group named $Name")) {
                try {
                    # Add replicas
                    $null = Add-DbaAgReplica @replicaparams -EnableException -SqlInstance $second
                } catch {
                    Stop-Function -Message "Failure" -ErrorRecord $_ -Target $second -Continue
                }
            }
        }

        try {
            # something is up with .net create(), force a stop
            Invoke-Create -Object $ag
        } catch {
            $msg = $_.Exception.InnerException.InnerException.Message
            if (-not $msg) {
                $msg = $_
            }
            Stop-Function -Message $msg -ErrorRecord $_ -Target $Primary
            return
        }

        # Add listener
        if ($IPAddress -or $Dhcp) {
            $progressmsg = "Adding listener"
        } else {
            $progressmsg = "Joining availability group"
        }
        Write-ProgressHelper -StepNumber ($stepCounter++) -Message $progressmsg

        if ($Distrbuted) {
            $ListenerName = $DagListnerName
        }
        if ($IPAddress) {
            if ($Pscmdlet.ShouldProcess($Primary, "Adding static IP listener for $Name to the Primary replica")) {
                $null = Add-DbaAgListener -Name $ListenerName -InputObject $ag -IPAddress $IPAddress -SubnetMask $SubnetMask -Port $Port -Dhcp:$Dhcp
            }
        } elseif ($Dhcp) {
            if ($Pscmdlet.ShouldProcess($Primary, "Adding DHCP listener for $Name to all replicas")) {
                $null = Add-DbaAgListener -InputObject $ag -Port $Port -Dhcp:$Dhcp
                foreach ($second in $secondaries) {
                    $secag = Get-DbaAvailabilityGroup -SqlInstance $second -AvailabilityGroup $Name
                    $null = Add-DbaAgListener -InputObject $secag -Port $Port -Dhcp:$Dhcp
                }
            }
        }

        Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Joining availability group"

        foreach ($second in $secondaries) {
            if ($Pscmdlet.ShouldProcess("Joining $($second.Name) to $Name")) {
                try {
                    # join replicas to ag
                    Join-DbaAvailabilityGroup -SqlInstance $second -InputObject $ag -EnableException
                } catch {
                    Stop-Function -Message "Failure" -ErrorRecord $_ -Target $second -Continue
                }
            }
        }

        Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Granting permissions on availability group, this may take a moment"

        # Grant permissions, but first, get all necessary service accounts
        $primaryserviceaccount = $server.ServiceAccount.Trim()
        $saname = ([DbaInstanceParameter]($server.DomainInstanceName)).ComputerName

        if ($primaryserviceaccount) {
            if ($primaryserviceaccount.StartsWith("NT ")) {
                $primaryserviceaccount = "$saname`$"
            }
            if ($primaryserviceaccount.StartsWith("$saname")) {
                $primaryserviceaccount = "$saname`$"
            }
            if ($primaryserviceaccount.StartsWith(".")) {
                $primaryserviceaccount = "$saname`$"
            }
        }

        if (-not $primaryserviceaccount) {
            $primaryserviceaccount = "$saname`$"
        }

        $serviceaccounts = @($primaryserviceaccount)

        foreach ($second in $secondaries) {
            # If service account is empty, add the computer account instead
            $secondaryserviceaccount = $second.ServiceAccount.Trim()
            $saname = ([DbaInstanceParameter]($second.DomainInstanceName)).ComputerName

            if ($secondaryserviceaccount) {
                if ($secondaryserviceaccount.StartsWith("NT ")) {
                    $secondaryserviceaccount = "$saname`$"
                }
                if ($secondaryserviceaccount.StartsWith("$saname")) {
                    $secondaryserviceaccount = "$saname`$"
                }
                if ($secondaryserviceaccount.StartsWith(".")) {
                    $secondaryserviceaccount = "$saname`$"
                }
            }

            if (-not $secondaryserviceaccount) {
                $secondaryserviceaccount = "$saname`$"
            }

            $serviceaccounts += $secondaryserviceaccount
        }

        $serviceaccounts = $serviceaccounts | Select-Object -Unique

        if ($SeedingMode -eq 'Automatic') {
            try {
                if ($Pscmdlet.ShouldProcess($server.Name, "Seeding mode is automatic. Adding CreateAnyDatabase permissions to availability group.")) {
                    $null = $server.Query("ALTER AVAILABILITY GROUP [$Name] GRANT CREATE ANY DATABASE")
                }
            } catch {
                # Log the exception but keep going
                Stop-Function -Message "Failure" -ErrorRecord $_
            }
        }

        # Add databases
        Write-ProgressHelper -StepNumber ($stepCounter++) -Message "Adding databases"
        $dbdone = $false
        do {
            foreach ($second in $secondaries) {
                if ($SeedingMode -eq 'Automatic') {
                    $done = $false
                    try {
                        if ($Pscmdlet.ShouldProcess($second.Name, "Seeding mode is automatic. Adding CreateAnyDatabase permissions to availability group.")) {
                            do {
                                $second.Refresh()
                                $second.AvailabilityGroups.Refresh()
                                if (Get-DbaAvailabilityGroup -SqlInstance $second -AvailabilityGroup $Name) {
                                    $null = $second.Query("ALTER AVAILABILITY GROUP [$Name] GRANT CREATE ANY DATABASE")
                                    $done = $true
                                } else {
                                    $wait++
                                    Start-Sleep -Seconds 1
                                }
                            } while ($wait -lt 20 -and $done -eq $false)
                        }
                    } catch {
                        # Log the exception but keep going
                        Stop-Function -Message "Failure" -ErrorRecord $_
                    }
                }
                if ($Database) {
                    $null = Add-DbaAgDatabase -SqlInstance $Primary -SqlCredential $PrimarySqlCredential -AvailabilityGroup $Name -Database $Database -SeedingMode $SeedingMode -SharedPath $SharedPath -Secondary $Secondary -SecondarySqlCredential $SecondarySqlCredential
                }
            }

            if (Get-DbaAgDatabase -SqlInstance $Primary -SqlCredential $PrimarySqlCredential -AvailabilityGroup $Name -Database $Database) {
                $dbdone = $true
            } else {
                $null = Add-DbaAgDatabase -SqlInstance $Primary -SqlCredential $PrimarySqlCredential -AvailabilityGroup $Name -Database $Database -SeedingMode $SeedingMode -SharedPath $SharedPath -Secondary $Secondary -SecondarySqlCredential $SecondarySqlCredential -WarningAction SilentlyContinue
                $dbwait++
                Start-Sleep -Seconds 1
            }
        } while ($dbwait -lt 20 -and $dbdone -eq $false)

        # Get results
        Get-DbaAvailabilityGroup -SqlInstance $Primary -SqlCredential $PrimarySqlCredential -AvailabilityGroup $Name
    }
}
