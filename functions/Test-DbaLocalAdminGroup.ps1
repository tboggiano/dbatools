function Test-DbaLocalAdminGroup {
    <#
    .SYNOPSIS
        Test if login is member of the Administrators Group.

    .DESCRIPTION
        Test if login is a member of the Administrators Group on a computer

    .PARAMETER ComputerName
        Computer to connect.

    .PARAMETER LoginName
        Login to test.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: permission
        Author: Shawn Melton (@wsmelton)
        Source: http://www.lazywinadmin.com/2012/12/get-localgroupmembership-using-adsiwinnt.html

        Website: https://dbatools.io
        Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Get-DbaLogin

    .EXAMPLE
        An example
    #>
    [cmdletbinding()]
    param(
        [DbaInstanceParameter[]]$ComputerName,
        [string[]]$LoginName,
        [Alias('Silent')]
        [switch]$EnableException
    )
    begin {
        if (Test-Bound 'LoginName' -Not) {
            Stop-Function -Message "No LoginName was provided."
        }
    }
    process {
        foreach ($computer in $ComputerName) {
            Write-Message -Level System -Message "Resolving computer name"
            $resolved = Resolve-DbaNetworkName -ComputerName $computer

            Write-Message -Level System -Message "Collecting Administrators Group members on $computer"
            try {
                $members = Get-DbaLocalGroupMembership -ComputerName $resolved.FQDN
            }
            catch {
                Stop-Function -Message "Unable to collect members of Administrator Group" -ErrorRecord $_ -Target $computer -Continue
            }

            if ($members) {
                foreach ($login in $LoginName) {
                    [pscustomobject]@{
                        ComputerName = $resolved.ComputerName
                        Login        = $login
                        IsMember     = ($login -in $members.Account)
                    }
                }
            }
        }
    }
}