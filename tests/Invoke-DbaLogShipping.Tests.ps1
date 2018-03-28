$commandname = $MyInvocation.MyCommand.Name.Replace(".Tests.ps1", "")
Write-Host -Object "Running $PSCommandpath" -ForegroundColor Cyan
. "$PSScriptRoot\constants.ps1"

Describe "$commandname Integration Tests" -Tags "IntegrationTests" {
    BeforeAll {
        $dbname = "dbatoolsci_logshipping"
        Get-DbaProcess -SqlInstance $script:instance2 -Program 'dbatools PowerShell module - dbatools.io' | Stop-DbaProcess
        $server = Connect-DbaInstance -SqlInstance $script:instance2
        $server.Query("CREATE DATABASE $dbname; ALTER DATABASE $dbname SET AUTO_CLOSE OFF WITH ROLLBACK IMMEDIATE")
    }
    AfterAll {
        Get-DbaDatabase -SqlInstance $script:instance2, $script:instance3 -Database $dbname | Remove-DbaDatabase -Confirm:$false
    }
    
    It -Skip "sets up log shipping properly" {
        $results = Invoke-DbaLogShipping -SourceSqlInstance $script:instance2 -DestinationSqlInstance $script:instance3 -Database $dbname -BackupNetworkPath C:\temp -BackupLocalPath "C:\temp\logshipping\backup" -GenerateFullBackup -CompressBackup -SecondaryDatabaseSuffix "_LS" -Force
        $results.Status -eq 'Success' | Should Be $true
    }
}