param(
    [Alias("d", "directorio")][string]$dir,
    [Alias("p")][string]$palabras,
    [Alias("l")][string]$log,
    [Alias("k")][switch]$kill,
    [switch]$daemon 
)


# Validaciones Iniciales

if (-not $dir) {
    Write-Host "Error: El parámetro -d / -directorio es obligatorio." -ForegroundColor Red
    exit
}

$dirFullPath = [System.IO.Path]::GetFullPath($dir)

if (-not (Test-Path $dirFullPath) -and -not $kill) {
    Write-Host "Error: El directorio '$dirFullPath' no existe." -ForegroundColor Red
    exit
}

$md5 = [System.Security.Cryptography.MD5]::Create()
$hashBytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($dirFullPath))
$hashString = [System.BitConverter]::ToString($hashBytes) -replace '-'

$tempDir = [System.IO.Path]::GetTempPath()
$pidFileName = "demonio_$hashString.pid"
$pidFile = Join-Path -Path $tempDir -ChildPath $pidFileName


# Lógica de Finalización (-kill)

if ($kill) {
    if (Test-Path $pidFile) {
        $targetPid = Get-Content $pidFile
        $process = Get-Process -Id $targetPid -ErrorAction SilentlyContinue
        if ($process) {
            Stop-Process -Id $targetPid -Force
            Write-Host "Demonio en '$dirFullPath' detenido exitosamente (PID $targetPid)." -ForegroundColor Green
        } else {
            Write-Host "El proceso ya no estaba en ejecución. Limpiando registro..." -ForegroundColor Yellow
        }
        Remove-Item $pidFile -Force
    } else {
        Write-Host "No hay ningún demonio en ejecución para el directorio: $dirFullPath" -ForegroundColor Yellow
    }
    exit
}


# Validaciones para Inicio

if (-not $palabras -or -not $log) {
    Write-Host "Error: Faltan parámetros (-p/-palabras y -l/-log son obligatorios)." -ForegroundColor Red
    exit
}

$logFullPath = [System.IO.Path]::GetFullPath($log)

if (Test-Path $pidFile) {
    $existingPid = Get-Content $pidFile
    if (Get-Process -Id $existingPid -ErrorAction SilentlyContinue) {
        Write-Host "Error: Ya existe un demonio en ejecución para '$dirFullPath'." -ForegroundColor Red
        exit
    } else {
        Remove-Item $pidFile -Force
    }
}

if (-not $daemon) {
    if ($IsLinux) {
        $psExe = "pwsh"
        $argsList = "-File `"$PSCommandPath`" -d `"$dirFullPath`" -p `"$palabras`" -l `"$logFullPath`" -daemon"
    } else {
        $psExe = "powershell.exe"
        $argsList = "-WindowStyle Hidden -File `"$PSCommandPath`" -d `"$dirFullPath`" -p `"$palabras`" -l `"$logFullPath`" -daemon"
    }
    
    Start-Process $psExe -ArgumentList $argsList
    Write-Host "Demonio iniciado en segundo plano. Monitoreando: $dirFullPath" -ForegroundColor Green
    exit
}


# Ejecución del Demonio

$PID | Out-File -FilePath $pidFile -Force

$script:regexPattern = $palabras -replace ",", "|"
$script:logPath = $logFullPath

function Log-Event($filePath, $op) {
    $fileInfo = Get-Item $filePath
    $size = $fileInfo.Length
    $datetime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $mensaje = "[$datetime] Operación: $op | Archivo: $filePath | Tamaño: $size bytes"
    Add-Content -Path $script:logPath -Value $mensaje
}

Get-ChildItem -Path $dirFullPath -File | ForEach-Object {
    if (Select-String -Path $_.FullName -Pattern $script:regexPattern -Quiet -ErrorAction SilentlyContinue) {
        Log-Event $_.FullName "EXISTENTE (Escaneo Inicial)"
    }
}

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $dirFullPath
$watcher.IncludeSubdirectories = $false

$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor 
                        [System.IO.NotifyFilters]::FileName -bor 
                        [System.IO.NotifyFilters]::Size

$eventData = @{
    RegexPattern = ($palabras -replace ",", "|")
    LogPath      = $logFullPath
}

$action = {
    $path = $Event.SourceEventArgs.FullPath
    $changeType = $Event.SourceEventArgs.ChangeType
    
    $pattern = $Event.MessageData.RegexPattern
    $log = $Event.MessageData.LogPath
    
    Start-Sleep -Milliseconds 500 
    
    if (Test-Path $path -PathType Leaf) {
        try {
            if (Select-String -Path $path -Pattern $pattern -Quiet -ErrorAction Stop) {
                $size = (Get-Item $path).Length
                $datetime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $mensaje = "[$datetime] Operación: NUEVO/MODIFICADO ($changeType) | Archivo: $path | Tamaño: $size bytes"
                
                Add-Content -Path $log -Value $mensaje -ErrorAction SilentlyContinue
            }
        } catch {
        }
    }
}

Register-ObjectEvent $watcher "Created" -MessageData $eventData -Action $action > $null
Register-ObjectEvent $watcher "Changed" -MessageData $eventData -Action $action > $null
Register-ObjectEvent $watcher "Renamed" -MessageData $eventData -Action $action > $null

$watcher.EnableRaisingEvents = $true

while ($true) {
    Start-Sleep -Seconds 10
}