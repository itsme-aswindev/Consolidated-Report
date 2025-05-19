param (
    [string]$ScriptPath = $PSScriptRoot,
    [string]$SMTPServer = "SMTP server Address",
    [string]$FromEmail = "email@email.com",
    [string[]]$ToEmail = @("email-1@email.com", "email-2@email.com")
)

# Get current date in a readable format (e.g., 20-Feb-2025)

$CurrentDate = Get-Date -Format "dd-MMM-yyyy"


# Construct the subject with the current date

$EmailSubject = "Consolidated Report - $CurrentDate"

$RoboVMFile = Join-Path $ScriptPath "Robo-VM.csv"
$DCVMFile = Join-Path $ScriptPath "DC-VM.csv"
$HVFile = Join-Path $ScriptPath "HV.csv"
$PLCFile = Join-Path $ScriptPath "PLC.csv"
$LogFile = Join-Path $ScriptPath "Log\PingReport.log"

# Function to log messages and display runtime output
function Write-Log {
    param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -Append -FilePath $LogFile
    Write-Host $Message
}

function Test-ConnectionStatus {
    param ([string]$ComputerName)
    return Test-Connection -ComputerName $ComputerName -Count 2 -Quiet
}

# Read CSV files
Write-Log "Reading CSV files..."
$RoboVMs = Import-Csv -Path $RoboVMFile
$DCVMs = Import-Csv -Path $DCVMFile
$HyperVs = Import-Csv -Path $HVFile
$PLCs = Import-Csv -Path $PLCFile

$SiteSummary = @{}
$UnreachableSystems = @()
$ReachableSystems = @()

# Process Hyper-V and VM Data
foreach ($vm in $RoboVMs) {
    $VMName = $vm.VMName
    $HyperVName = $vm.HyperVHost
    $SiteName = $vm.Site
    
    if (-not $SiteSummary[$SiteName]) {
        $SiteSummary[$SiteName] = @{TotalVMs=0; TotalHVs=0; Up=0; Down=0; HyperVs=@{}}
    }
    $SiteSummary[$SiteName].TotalVMs++

    Write-Log "Pinging CI: $VMName"
    if (Test-ConnectionStatus -ComputerName $VMName) {
        $SiteSummary[$SiteName].Up++
        $ReachableSystems += $VMName
    } else {
        $SiteSummary[$SiteName].Down++
        $UnreachableSystems += [PSCustomObject]@{ "Name" = $VMName; "Type" = "VM/HV"; "Host" = $HyperVName; "Site" = $SiteName }
    }
    
    if (-not $SiteSummary[$SiteName].HyperVs[$HyperVName]) {
        $SiteSummary[$SiteName].TotalHVs++
        $SiteSummary[$SiteName].HyperVs[$HyperVName] = $false
    }
}

# Process PLC Devices
foreach ($plc in $PLCs) {
    $PLCName = $plc.PLCName
    $IP = $plc.IP
    $Location = $plc.Location
    
    Write-Log "Pinging PLC: $PLCName ($IP)"
    if (Test-ConnectionStatus -ComputerName $IP) {
        $ReachableSystems += $PLCName
    } else {
        $UnreachableSystems += [PSCustomObject]@{ "Name" = $PLCName; "Type" = "PLC Device"; "IP" = $IP; "Site" = $Location }
    }
}

# AD Replication Summary
Write-Log "Checking AD Replication Status..."
$ADReplicationRaw = repadmin /replsummary | Out-String
$ADReplicationStatus = if ($ADReplicationRaw -match "0") { "Good" } else { "Issues Detected" }
echo $ADReplicationStatus

# Generate HTML Report
$ReportFile = Join-Path $ScriptPath "Consolidated_Report.html"
$HTMLReport = @"
<!DOCTYPE html>
<html lang='en'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1'>
    <title>Consolidated Report</title>
    <style>
        body { font-family: Arial, sans-serif; background-color: #f4f4f4; padding: 20px; }
        .container { max-width: 900px; margin: auto; background: #fff; padding: 20px; border-radius: 10px; box-shadow: 0px 4px 10px rgba(0, 0, 0, 0.1); }
        h2 { color: #333; text-align: center; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; text-align: center; border: 1px solid #ddd; font-weight: bold; }
        th { background-color: #007bff; color: white; font-size: 14px; }
        .highlight { color: red; font-weight: bold; }
        .good-status { background-color: #28a745; color: white; }
        .issue-status { background-color: #ffbf00; color: black; }
        .fade-in { animation: fadeIn 1.2s ease-in-out; }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(-10px); }
            to { opacity: 1; transform: translateY(0); }
        }
    </style>
</head>
<body>
    <div class='container fade-in'>
        <h2>Consolidated Report - Infra & AD </h2>
        <p>Hi All,</p>
        <p>Please find the consolidated report of all VMs and PLC devices.<br> All the CI's are up and running fine except the ones listed below.</p>
        
        <h3 class='highlight'>Unreachable CI's</h3>
        <table>
            <tr><th>Name</th><th>Type</th><th>Host</th><th>Site</th></tr>
            $(foreach ($system in $UnreachableSystems) {
                "<tr><td>$($system.Name)</td><td>$($system.Type)</td><td>$($system.Host) $($system.IP)</td><td>$($system.Site)</td></tr>"
            })
        </table>

        <h3>Summary</h3>
        <table>
            <tr><th>Locations</th><th>Total CI's</th><th>Devices UP</th><th>Devices DOWN</th><th>Overall Status</th></tr>
            $(foreach ($site in $SiteSummary.Keys) {
                $status = if ($SiteSummary[$site].Down -eq 0) { "Good" } else { "Issues Detected" }
                $statusClass = if ($SiteSummary[$site].Down -eq 0) { "good-status" } else { "issue-status" }
                "<tr>
                    <td>$site</td>
                    <td>$($SiteSummary[$site].TotalVMs)</td>
                    <td>$($SiteSummary[$site].Up)</td>
                    <td>$($SiteSummary[$site].Down)</td>
                    <td class='$statusClass'>$status</td>
                </tr>"
            })
        </table>

        <h3>AD Replication Summary</h3>
        <table>
            <tr><th>Replication Status</th></tr>
            <tr class='$(if ($ADReplicationStatus -match "Good") { "good-status" } else { "issue-status" })'>
                <td>$ADReplicationStatus</td>
            </tr>
        </table>
    </div>
</body>
</html>
"@

$HTMLReport | Out-File -FilePath $ReportFile
Write-Log "HTML report generated: $ReportFile"


Send-MailMessage -SmtpServer $SMTPServer -From $FromEmail -To $ToEmail -Subject $EmailSubject -BodyAsHtml -Body (Get-Content $ReportFile -Raw)
Write-Log "Email sent successfully."
