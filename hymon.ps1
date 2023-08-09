if ($args.Length -lt 1) { Write-Host "Usage: hymon ./config.txt"; Exit }
try {
    $config = Get-Content -Raw $args[0];

} catch { throw $_ }

function GetLongest {
    param ($Usage, $Maximum)
    if ($usage.Length -ne $Maximum.Length) { Write-Error "GetLongest fonction: -Usage length is not equal to -Maximum length"; Exit }
    $length = 0;
    for ($i = 0; $i -lt $Usage.Length; $i++) {
        if ((([string]$Usage[$i]).Length + ([string]$Maximum[$i]).Length) -gt $length) { $length = ([string]$Usage[$i]).Length + ([string]$Maximum[$i]).Length }
    }
    return $length;
}
#$crs_start = $host.UI.RawUI.CursorPosition;
# FAIRE UNE CONNEXION EN BOUCLE JUSQUA ETABLISSEMENT AVEC MESSAGE "Connexion en cours..."
$session_tab = @();
$hypervisors = $config -split "`r`n`r`n";
$i = 0;
$hvTab = @();
while ($i -lt $hypervisors.Length) {
    $hv = $hypervisors[$i];
    $prm = $hv -split "`r`n";
    $hvName = $prm[1];
    $sshHost = $prm[2];
    $sshUser = $prm[3];
    $sshPass = ConvertTo-SecureString $prm[4] -AsPlainText -Force;
    $cred = New-Object System.Management.Automation.PSCredential($sshUser, $sshPass);
    try {
        $sess = New-SSHSession -ComputerName $sshHost -Credential $cred;
        $session_tab += $sess
        $i++;
        $hvTab += @{ vms = @(); name = $hvName; host = $sshHost }
    } catch {     Start-Sleep -Seconds 4; }
}

while (1) {
    $hvTabIdx = 0;
    foreach ($session in $session_tab) {
        #$hv = $hypervisors[$hv_idx];
        if ($prm[0] -eq "ESXI") {

            $VMs = Invoke-SSHCommand -SessionId $session.SessionId -Command "vim-cmd vmsvc/getallvms";
            $VMs = $VMs.Output;
            $vmTab = @();
            for ($i = 1; $i -lt $VMs.Length; $i++) {
                $vm = (($VMs[$i]).Split('', [System.StringSplitOptions]::RemoveEmptyEntries) -join ' ') -split ' ';
                $state = Invoke-SSHCommand -SessionId $session.SessionId -Command "vim-cmd vmsvc/get.summary $($vm[0])"
                $state = $state.Output -join "`n";
                $pwrState = $state.Substring($state.IndexOf("powerState = ") + 21, 2);
                if ($pwrState -eq "On") { $pwrState = "Active" } else { $pwrState = "Inactive" }
                $maxCpu = $state.Substring(($idx = $state.IndexOf("maxCpuUsage = ") + 14), ($state.IndexOf(",", $idx) - $idx));
                $maxMem = $state.Substring(($idx = $state.IndexOf("maxMemoryUsage = ") + 17), ($state.IndexOf(",", $idx) - $idx));
                $ip = $state.Substring(($idx = $state.IndexOf("ipAddress = ") + 13), (($state.IndexOf(",", $idx) - 1) - $idx));
                $numCpu = $state.Substring(($idx = $state.IndexOf("numCpu = ") + 9), ($state.IndexOf(",", $idx) - $idx));
                $storeUsed = $state.Substring(($idx = $state.IndexOf("committed = ") + 11), ($state.IndexOf(",", $idx) - $idx));
                $storeUnused = $state.Substring(($idx = $state.IndexOf("uncommitted = ") + 13), ($state.IndexOf(",", $idx) - $idx));
                $memUsage = $state.Substring(($idx = $state.IndexOf("guestMemoryUsage = ") + 19), ($state.IndexOf(",", $idx) - $idx));
                if ($memUsage[0] -eq "<") { $memUsage = 0 }
                $cpuUsage = $state.Substring(($idx = $state.IndexOf("overallCpuUsage = ") + 18), ($state.IndexOf(",", $idx) - $idx));
                if ($cpuUsage[0] -eq "<") { $cpuUsage = 0 }
                $vmTab += @{
                    id = $vm[0];
                    name = $vm[1];
                    store = $vm[2];
                    #os = $vm[4].Substring(0, $vm[4].IndexOf("_"));
                    pwrState = $pwrState;
                    maxCpu = [System.Math]::Round($maxCpu / 1000, 1);
                    maxMem = [System.Math]::Round($maxMem / 1000, 0);
                    ip = $ip;
                    numCpu = $numCpu;
                    storeUsed = [System.Math]::Round($storeUsed / 1000000000, 1);
                    storeUnused = [System.Math]::Round($storeUnused / 1000000000, 1);
                    memUsage = [System.Math]::Round($memUsage / 1000, 2);
                    cpuUsage = [System.Math]::Round($cpuUsage / 1000, 2);
                }
            }
        }
        ## Modification Vendredi Aprem
        $hvTab[$hvTabIdx].vms = $vmTab;
        $hvTabIdx++;
    }
    <#$tmp = $crs_end.X;
    while ($crs_end.Y -gt $crs_start.Y) {
        $crs_end.Y--;
        $crs_end.X = 0;
        $host.UI.RawUI.CursorPosition = $crs_end;
        Write-Host (" " * $tmp);
    }#>
    #Write-Host " -----------------------------------------------" -ForegroundColor Red
    Clear-Host
    foreach ($hv in $hvTab) {
        Write-Host "`n $($hv.name): $($hv.host)" -ForegroundColor Yellow;
        Write-Host ""("-" * ($hv.name.Length + $hv.host.Length + 2)) -ForegroundColor Yellow;
        $vmNameLength = ($hv.vms.name | Measure-Object -Maximum -Property Length).Maximum;
        $vmIdLength = ($hv.vms.id | Measure-Object -Maximum -Property Length).Maximum;
        $vmStateLength = ($hv.vms.pwrState | Measure-Object -Maximum -Property Length).Maximum;
        $vmStoreLength = ($hv.vms.store | Measure-Object -Maximum -Property Length).Maximum;
        #$vmOsLength = ($hv.vms.os | Measure-Object -Maximum -Property Length).Maximum;
        $vmIpLength = ($hv.vms.ip | Measure-Object -Maximum -Property Length).Maximum;
        $vmMemLength = GetLongest -Usage $hv.vms.memUsage -Maximum $hv.vms.maxMem;
        $vmCpuLength = GetLongest -Usage $hv.vms.cpuUsage -Maximum $hv.vms.maxCpu;
        $vmNumCpuLength = ($hv.vms.numCpu | Measure-Object -Maximum -Property Length).Maximum;
        $vmStorageLength = GetLongest -Usage $hv.vms.storeUsed -Maximum $hv.vms.storeUnused;


        if ($vmIpLength -lt 7) { $vmIpLength = 7 } if ($vmIdLength -lt 2) { $vmIdLength = 2 }
        $lineClr = "White";
        $vNameL = $vmNameLength - 4; $vIdL = $vmIdLength - 2; $vStateL = $vmStateLength - 5; $vStoreL = $vmStoreLength - 5; $vIpL = $vmIpLength - 7; $vMemL = $vmMemLength - 1; $vCpuL = $vmCpuLength - 9 + 4; $vNumCpuL = $vmNumCpuLength - 1; 
        if (($vmNameLength - 4) -lt 1) { $vNameL = 1 } if (($vmIdLength - 2) -lt 0) { $vIdL = 0 } if (($vmStateLength - 5) -lt 0) { $vStateL = 1 } if (($vmStoreLength - 5) -le 0) { $vStoreL = 0 } if (($vmIpLength - 5) -le 0) { $vIpL = 1 } if (($vmMemLength - 1) -lt 0) { $vMemL = 1 } if (($vmCpuLength - 9 + 3) -lt 0) { $vCpuL = 4 } if (($vmNumCpuLength - 1) -lt 0) { $vNumCpuL = 1 } #if (($vStateL - 4) -lt 0) { $vStorageL = 1 }
        Write-Host "   Name"(" " * ($vNameL)) " Id"(" " * ($vIdL)) " State"(" " * ($vStateL)) " Store"(" " * ($vStoreL)) " Address"(" " * ($vIpL)) " RAM"(" " * ($vMemL)) " CPU Speed"(" " * ($vCpuL)) "Thd"(" " * ($vNumCpuL)) "Storage"(" " * ($vStorageL));
        Write-Host "  "("-" * $vmNameLength) " " ("-" * $vmIdLength) " " ("-" * $vmStateLength) " " ("-" * $vmStoreLength) " " ("-" * $vmIpLength) " " ("-" * ($vmMemLength + 2)) " " ("-" * ($vmCpuLength + 3)) " " ("-" * ($vmNumCpuLength + 2)) ""("-" * ($vmStorageLength + 3));
        foreach ($vm in $hv.vms) {
            Write-Host -n "  "$vm.name (" " * ($vmNameLength - $vm.name.Length))-ForegroundColor $lineClr;
            Write-Host -n "|"$vm.id (" " * ($vmIdLength - $vm.id.Length)) -ForegroundColor $lineClr;
            if ($vm.pwrState -eq "Active") { $clr = "Green" } else { $clr = "Red" }
            Write-Host -n "| " -ForegroundColor $lineClr;
            Write-Host -n $vm.pwrState (" " * ($vmStateLength - $vm.pwrState.Length)) -ForegroundColor $clr;
            Write-Host -n "|"$vm.store (" " * ($vmStoreLength - $vm.store.Length)) -ForegroundColor $lineClr;
            Write-Host -n "| " -ForegroundColor $lineClr;
            Write-Host -n $vm.ip (" " * ($vmipLength - $vm.ip.Length)) -ForegroundColor $clr;
            #Write-Host -n $vm.os (" " * ($vmOsLength - $vm.os.Length)) -ForegroundColor $lineClr;
            Write-Host -n "|" "$($vm.memUsage)/$($vm.maxMem)G" (" " * (($vmMemLength) - (([string]$vm.memUsage).Length + ([string]$vm.maxMem).Length))) -ForegroundColor $lineClr;
            Write-Host -n "|" "$($vm.cpuUsage)/$($vm.maxCpu)Ghz" (" " * (($vmCpuLength) - (([string]$vm.cpuUsage).Length + ([string]$vm.maxCpu).Length))) -ForegroundColor $lineClr;
            Write-Host -n "|"$vm.numCpu (" " * ($vmNumCpuLength - $vm.numCpu.Length)) -ForegroundColor $lineClr;
            $maxStorage = $vm.storeUsed + $vm.storeUnused;
            Write-Host -n "|" "$($vm.storeUsed)/$($maxStorage)G" (" " * ($vmStorageLength - ($vm.storeUsed.Length + $vm.storeUnused.Length))) -ForegroundColor $lineClr;
            #$crs_end = $host.UI.RawUI.CursorPosition;
            Write-Host "";
            if ($lineClr -eq "White") { $lineClr = "Yellow" } else { $lineClr = "White" }
            #$vmCpuLength - ($vm.cpuUsage.Length + $vm.cpuMem.Length)
        }
        Write-Host "  "("-" * $vmNameLength) " " ("-" * $vmIdLength) " " ("-" * $vmStateLength) " " ("-" * $vmStoreLength) " " ("-" * $vmIpLength) " " ("-" * ($vmMemLength + 2)) " " ("-" * ($vmCpuLength + 3)) " " ("-" * ($vmNumCpuLength + 2)) ""("-" * ($vmStorageLength + 3));
    }
        Start-Sleep -Seconds 1
}
$rmSession = Remove-SSHSession -SessionId $session.SessionId;
