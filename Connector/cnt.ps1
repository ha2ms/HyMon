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
$host.UI.RawUI.CursorSize = 0;
while ($i -lt $hypervisors.Length) {
    $hv = $hypervisors[$i];
    $prm = $hv -split "`r`n";
    $hvName = $prm[1];
    $sshHost = $prm[2];
    $sshUser = $prm[3];
    $sshPass = ConvertTo-SecureString $prm[4] -AsPlainText -Force;
    $cred = New-Object System.Management.Automation.PSCredential($sshUser, $sshPass);
    $job = Start-Job -ArgumentList $sshHost, $cred, $hvName -ScriptBlock {
        $sshHost = $args[0]; $cred = $args[1]; $hvName = $args[2];
        try {
            $sess = New-SSHSession -ComputerName $sshHost -Credential $cred;
            return $sess
        } catch { return "err" }
    }
    if (($job.Sate -eq "Completed") -and (Receive-Job $job -ne "err")) {
        $session_tab += $sess
        $hvTab += @{ vms = @(); name = $hvName; host = $sshHost }    
        $i++;
    } else {
        $crs = $host.UI.RawUI.CursorPosition;
        Write-Host -n "Connexion vers ";
        Write-Host -n -ForegroundColor Yellow "[ $hvName ]                  ";
        Write-Host -ForegroundColor Red " [ En Cours ]";
        for ($load = 0; $load -lt 16; $load++) {
            $crs.X = $load + 20 + $hvName.Length;
            $host.UI.RawUI.CursorPosition = $crs;
            Write-Host -n "=>"
            Start-Sleep -Milliseconds 80
        }
        $crs.X = 20 + $hvName.Length
        $host.UI.RawUI.CursorPosition = $crs;
        Write-Host -n "                 "
        $crs.X = 0
        $host.UI.RawUI.CursorPosition = $crs;
    }
}
