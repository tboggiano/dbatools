function Get-DbaLocalGroupMembership {
    <#
    .Synopsis
        Get the local group membership.

    .Description
        Get the local group membership.

    .Parameter ComputerName
        Name of the Computer to get group members. Default is "localhost".

    .Parameter GroupName
        Name of the GroupName to get members from. Default is "Administrators".

    .Example
        Get-LocalGroupMembership
        Description
        -----------
        Get the Administrators group membership for the localhost

    .Example
        Get-LocalGroupMembership -ComputerName SERVER01 -GroupName "Remote Desktop Users"
        Description
        -----------
        Get the membership for the the group "Remote Desktop Users" on the computer SERVER01

    .Example
        Get-LocalGroupMembership -ComputerName SERVER01,SERVER02 -GroupName "Administrators"
        Description
        -----------
        Get the membership for the the group "Administrators" on the computers SERVER01 and SERVER02

    .Notes
        NAME:      Get-LocalGroupMembership
        AUTHOR:    Francois-Xavier Cat
        WEBSITE:   www.LazyWinAdmin.com
        Source: http://www.lazywinadmin.com/2012/12/get-localgroupmembership-using-adsiwinnt.html
    #>

    [Cmdletbinding()]
    param (
        [DbaInstanceParameter[]]$ComputerName = $env:COMPUTERNAME,
        [string]$GroupName = "Administrators",
        [Alias('Silent')]
        [switch]$EnableException
    )
    process {
        foreach ($computer in $ComputerName) {
            try {
                $everythingOk = $true

                # Get the members for the group and computer specified
                $Group = [ADSI]"WinNT://$computer/$GroupName,group"
                $Members = @($group.psbase.Invoke("Members"))
            }
            catch {
                $everythingOk = $false
                throw $_
            }

            if ($everythingOk) {
                # Format the Output
                $members | Foreach-Object {
                    $name = $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)
                    $class = $_.GetType().InvokeMember("Class", 'GetProperty', $null, $_, $null)
                    $path = $_.GetType().InvokeMember("ADsPath", 'GetProperty', $null, $_, $null)

                    # Find out if this is a local or domain object
                    if ($path -like "*/$Computer/*") {
                        $Type = "Local"
                    }
                    else {
                        $Type = "Domain"
                    }

                    [PSCustomObject]@{
                        ComputerName = $Computer
                        Account      = $name
                        Class        = $class
                        Group        = $GroupName
                        Type         = $type
                    }
                }
            }
        }
    }
}