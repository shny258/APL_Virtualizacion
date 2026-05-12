# Integrantes del equipo: Tomas Ballesteros, Nicolas Catania, Rodrigo Ezequiel Aragón, Villan Matias Nicolas, Luciano Martins Louro

param(
    # ParameterSet 'Iniciar': Obliga a tener dir, palabras y log.
    [Parameter(Mandatory=$true, ParameterSetName='Iniciar', HelpMessage="El directorio a monitorear es obligatorio.")]
    # ParameterSet 'Detener': Obliga a tener dir y kill.
    [Parameter(Mandatory=$true, ParameterSetName='Detener', HelpMessage="El directorio es obligatorio para saber qué demonio detener.")]
    [Alias("d", "directorio")]
    [string]$dir,

    [Parameter(Mandatory=$true, ParameterSetName='Iniciar', HelpMessage="Debe especificar las palabras a buscar (-p).")]
    [Alias("p")]
    [string]$palabras,

    [Parameter(Mandatory=$true, ParameterSetName='Iniciar', HelpMessage="Debe especificar la ruta del archivo de log (-l).")]
    [Alias("l")]
    [string]$log,

    [Parameter(Mandatory=$true, ParameterSetName='Detener', HelpMessage="Use -kill para detener el proceso.")]
    [Alias("k")]
    [switch]$kill,

    # Parámetro oculto de uso interno para el ParameterSet 'Iniciar'
    [Parameter(Mandatory=$false, ParameterSetName='Iniciar')]
    [switch]$daemon 
)

$ErrorActionPreference = "Stop"


# Funciones Auxiliares

function Get-DaemonTempFile {
    param ([string]$Path)
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $hashBytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Path))
    $hashString = [System.BitConverter]::ToString($hashBytes) -replace '-'
    
    $tempDir = [System.IO.Path]::GetTempPath()
    return Join-Path -Path $tempDir -ChildPath "demonio_$hashString.pid"
}

function Stop-Demonio {
    param ([string]$TargetDir, [string]$PidFile)
    
    if (Test-Path $PidFile) {
        $targetPid = Get-Content $PidFile
        $process = Get-Process -Id $targetPid -ErrorAction SilentlyContinue
        if ($process) {
            Stop-Process -Id $targetPid -Force
            Write-Host "Éxito: Demonio en '$TargetDir' detenido correctamente (PID $targetPid)." -ForegroundColor Green
        } else {
            Write-Host "Aviso: El proceso ya no estaba en ejecución. Limpiando archivos residuales..." -ForegroundColor Yellow
        }
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "Aviso: No se encontró ningún demonio activo para el directorio '$TargetDir'." -ForegroundColor Yellow
    }
}

function Start-DemonioFondo {
    param ([string]$DirFullPath, [string]$LogFullPath, [string]$PalabrasClave, [string]$ScriptPath)
    
    if ($IsLinux) {
        $psExe = "pwsh"
        $argsList = "-File `"$ScriptPath`" -d `"$DirFullPath`" -p `"$PalabrasClave`" -l `"$LogFullPath`" -daemon"
    } else {
        $psExe = "powershell.exe"
        $argsList = "-WindowStyle Hidden -File `"$ScriptPath`" -d `"$DirFullPath`" -p `"$PalabrasClave`" -l `"$LogFullPath`" -daemon"
    }
    
    Start-Process $psExe -ArgumentList $argsList
    Write-Host "Éxito: Demonio iniciado en segundo plano. Monitoreando: $DirFullPath" -ForegroundColor Green
}

function Invoke-Monitoreo {
    param ([string]$DirFullPath, [string]$LogFullPath, [string]$PalabrasClave, [string]$PidFile)
    
    try {
        $PID | Out-File -FilePath $PidFile -Force

        $regexPattern = $PalabrasClave -replace ",", "|"

        Get-ChildItem -Path $DirFullPath -File | ForEach-Object {
            if (Select-String -Path $_.FullName -Pattern $regexPattern -Quiet -ErrorAction SilentlyContinue) {
                $size = (Get-Item $_.FullName).Length
                $datetime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                Add-Content -Path $LogFullPath -Value "[$datetime] Operación: EXISTENTE | Archivo: $($_.FullName) | Tamaño: $size bytes"
            }
        }

        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = $DirFullPath
        $watcher.IncludeSubdirectories = $false
        $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName -bor [System.IO.NotifyFilters]::Size

        $eventData = @{
            RegexPattern = $regexPattern
            LogPath      = $LogFullPath
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
                        Add-Content -Path $log -Value "[$datetime] Operación: NUEVO/MODIFICADO ($changeType) | Archivo: $path | Tamaño: $size bytes" -ErrorAction SilentlyContinue
                    }
                } catch {
                    # Ignorar si el archivo está temporalmente bloqueado
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
    }
    finally {
        if (Test-Path $PidFile) {
            Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
        }
    }
}

try {
    $dirFullPath = [System.IO.Path]::GetFullPath($dir)
    $pidFile = Get-DaemonTempFile -Path $dirFullPath

    if ($kill) {
        Stop-Demonio -TargetDir $dirFullPath -PidFile $pidFile
    }
    else {
        if (-not (Test-Path -LiteralPath $dirFullPath)) {
            throw "El directorio especificado '$dirFullPath' no existe o no se puede acceder a él."
        }

        $logFullPath = [System.IO.Path]::GetFullPath($log)

        if (Test-Path $pidFile) {
            $existingPid = Get-Content $pidFile
            if (Get-Process -Id $existingPid -ErrorAction SilentlyContinue) {
                throw "Ya existe un demonio en ejecución para el directorio '$dirFullPath'."
            } else {
                Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
            }
        }

        if (-not $daemon) {
            Start-DemonioFondo -DirFullPath $dirFullPath -LogFullPath $logFullPath -PalabrasClave $palabras -ScriptPath $PSCommandPath
        } else {
            Invoke-Monitoreo -DirFullPath $dirFullPath -LogFullPath $logFullPath -PalabrasClave $palabras -PidFile $pidFile
        }
    }
}
catch {
    Write-Host ""
    Write-Host "================ ATENCIÓN ================" -ForegroundColor Red
    Write-Host "Ocurrió un problema al ejecutar la herramienta:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor White
    Write-Host "Si necesita ayuda sobre cómo usar el comando, escriba: Get-Help $PSCommandPath" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host ""
}