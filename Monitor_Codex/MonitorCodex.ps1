# Monitor local de limite do Codex - Parmasoft
# Consulta somente o app-server local do Codex.
# Nao le auth.json, nao usa API key e nao envia dados a servidores de terceiros.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

# Ajustes
$RefreshSeconds = 180
$AlertRemaining = @(50, 25, 10, 5)

function Find-CodexExecutable {
    $cmd = Get-Command codex.exe -ErrorAction SilentlyContinue
    if (-not $cmd) { $cmd = Get-Command codex -ErrorAction SilentlyContinue }
    if ($cmd -and $cmd.Source) {
        return $cmd.Source
    }

    $roots = @(
        (Join-Path $env:USERPROFILE ".vscode\extensions"),
        (Join-Path $env:USERPROFILE ".vscode-insiders\extensions")
    )

    $candidates = @()
    foreach ($root in $roots) {
        if (Test-Path $root) {
            $candidates += Get-ChildItem -Path $root -Filter "codex.exe" -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.FullName -match "openai|chatgpt|codex"
                }
        }
    }

    if ($candidates.Count -gt 0) {
        return ($candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    }

    return $null
}

function Read-ResponseById {
    param(
        [System.Diagnostics.Process]$Process,
        [int]$Id,
        [int]$TimeoutMs = 10000
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $readTask = $Process.StandardOutput.ReadLineAsync()

    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        if ($readTask.Wait(250)) {
            $line = $readTask.Result
            if ($null -eq $line) { return $null }

            if (-not [string]::IsNullOrWhiteSpace($line)) {
                try {
                    $obj = $line | ConvertFrom-Json
                    if ($null -ne $obj.id -and [int]$obj.id -eq $Id) {
                        return $obj
                    }
                } catch {
                    # Ignora linhas que nao sejam JSON de resposta.
                }
            }

            $readTask = $Process.StandardOutput.ReadLineAsync()
        }
    }

    return $null
}

function Get-CodexRateLimits {
    param([string]$CodexPath)

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $CodexPath
    $psi.Arguments = "app-server"
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi

    try {
        [void]$p.Start()

        $init = @{
            method = "initialize"
            id = 1
            params = @{
                clientInfo = @{
                    name = "parmasoft_codex_quota_monitor"
                    title = "Parmasoft Codex Quota Monitor"
                    version = "1.0.0"
                }
            }
        } | ConvertTo-Json -Compress -Depth 6

        $p.StandardInput.WriteLine($init)
        $p.StandardInput.Flush()

        $initResp = Read-ResponseById -Process $p -Id 1 -TimeoutMs 10000
        if (-not $initResp -or $initResp.error) {
            throw "O Codex app-server nao respondeu corretamente ao initialize."
        }

        $initialized = @{
            method = "initialized"
            params = @{}
        } | ConvertTo-Json -Compress -Depth 4

        $request = @{
            method = "account/rateLimits/read"
            id = 2
        } | ConvertTo-Json -Compress -Depth 4

        $p.StandardInput.WriteLine($initialized)
        $p.StandardInput.WriteLine($request)
        $p.StandardInput.Flush()

        $resp = Read-ResponseById -Process $p -Id 2 -TimeoutMs 15000
        if (-not $resp) {
            throw "Sem resposta do account/rateLimits/read."
        }
        if ($resp.error) {
            throw ("Erro retornado pelo Codex: " + ($resp.error | ConvertTo-Json -Compress))
        }

        return $resp.result
    }
    finally {
        try { $p.StandardInput.Close() } catch {}
        try {
            if (-not $p.HasExited) {
                $p.Kill()
                $p.WaitForExit(1500) | Out-Null
            }
        } catch {}
        try { $p.Dispose() } catch {}
    }
}

function Convert-ResetTime {
    param($UnixSeconds)
    if ($null -eq $UnixSeconds) { return "sem horario" }
    try {
        return [DateTimeOffset]::FromUnixTimeSeconds([int64]$UnixSeconds).LocalDateTime.ToString("dd/MM HH:mm")
    } catch {
        return "sem horario"
    }
}

function Get-Buckets {
    param($Result)

    $rate = $null
    if ($Result.rateLimitsByLimitId -and $Result.rateLimitsByLimitId.codex) {
        $rate = $Result.rateLimitsByLimitId.codex
    } elseif ($Result.rateLimits) {
        $rate = $Result.rateLimits
    }

    if (-not $rate) { return @() }

    $items = @()
    foreach ($name in @("primary", "secondary")) {
        $b = $rate.$name
        if ($b -and $null -ne $b.usedPercent) {
            $duration = [int]$b.windowDurationMins
            $label = if ($duration -ge 10000) {
                "Semanal"
            } elseif ($duration -ge 240 -and $duration -le 360) {
                "5 horas"
            } elseif ($duration -ge 1440) {
                ("{0} dias" -f [Math]::Round($duration / 1440.0, 1))
            } else {
                ("{0} min" -f $duration)
            }

            $used = [double]$b.usedPercent
            $remaining = [Math]::Max(0, [Math]::Min(100, 100 - $used))

            $items += [pscustomobject]@{
                Name = $name
                Label = $label
                Duration = $duration
                Used = $used
                Remaining = $remaining
                ResetsAt = $b.resetsAt
                ResetText = Convert-ResetTime $b.resetsAt
            }
        }
    }
    return $items
}

$codexPath = Find-CodexExecutable
if (-not $codexPath) {
    [System.Windows.Forms.MessageBox]::Show(
        "Nao encontrei o executavel local do Codex.`r`n`r`nAbra o VS Code com a extensao Codex atualizada e tente novamente.",
        "Monitor de Limite do Codex",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    exit 1
}

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.Visible = $true
$notify.Text = "Monitor de Limite do Codex"

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$statusItem = New-Object System.Windows.Forms.ToolStripMenuItem
$statusItem.Text = "Aguardando leitura..."
$statusItem.Enabled = $false
[void]$menu.Items.Add($statusItem)

$refreshItem = New-Object System.Windows.Forms.ToolStripMenuItem
$refreshItem.Text = "Atualizar agora"
[void]$menu.Items.Add($refreshItem)

[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitItem.Text = "Sair"
[void]$menu.Items.Add($exitItem)

$notify.ContextMenuStrip = $menu

# Guarda quais alertas ja foram emitidos por janela/reset.
$alerted = @{}

function Show-UsageNotification {
    param(
        [string]$Title,
        [string]$Text,
        [System.Windows.Forms.ToolTipIcon]$Icon = [System.Windows.Forms.ToolTipIcon]::Info
    )
    $notify.BalloonTipTitle = $Title
    $notify.BalloonTipText = $Text
    $notify.BalloonTipIcon = $Icon
    $notify.ShowBalloonTip(7000)
}

function Update-Usage {
    try {
        $result = Get-CodexRateLimits -CodexPath $codexPath
        $buckets = @(Get-Buckets $result)

        if ($buckets.Count -eq 0) {
            $statusItem.Text = "Limites indisponiveis"
            $notify.Text = "Codex: limites indisponiveis"
            return
        }

        $parts = @()
        foreach ($b in $buckets) {
            $parts += ("{0}: {1:N0}% restante" -f $b.Label, $b.Remaining)

            foreach ($threshold in $AlertRemaining) {
                if ($b.Remaining -le $threshold) {
                    $key = "{0}|{1}|{2}" -f $b.Label, $b.ResetsAt, $threshold
                    if (-not $alerted.ContainsKey($key)) {
                        $alerted[$key] = $true

                        $icon = if ($threshold -le 10) {
                            [System.Windows.Forms.ToolTipIcon]::Error
                        } else {
                            [System.Windows.Forms.ToolTipIcon]::Warning
                        }

                        $mensagem = switch ($threshold) {
                            50 { "Restam {0:N0}% do limite. Continue normalmente, mas acompanhe o consumo. Reinicia em {1}." -f $b.Remaining, $b.ResetText }
                            25 { "Restam {0:N0}% do limite. Evite iniciar auditorias ou processos muito longos sem necessidade. Reinicia em {1}." -f $b.Remaining, $b.ResetText }
                            10 { "ATENCAO: restam {0:N0}% do limite. Nao inicie processo longo. Finalize o que estiver fazendo e atualize STATUS/documentacao antes de trocar de Codex. Reinicia em {1}." -f $b.Remaining, $b.ResetText }
                            5  { "CRITICO: restam {0:N0}% do limite. Hora de trocar a conta/Codex antes de continuar. Depois da troca, use 'Atualizar agora' para confirmar o novo saldo. Reinicia em {1}." -f $b.Remaining, $b.ResetText }
                            default { "Restam {0:N0}% do limite. Reinicia em {1}." -f $b.Remaining, $b.ResetText }
                        }

                        Show-UsageNotification `
                            -Title ("Codex - {0}" -f $b.Label) `
                            -Text $mensagem `
                            -Icon $icon
                    }
                }
            }
        }

        $summary = $parts -join " | "
        $statusItem.Text = $summary

        # NotifyIcon.Text aceita poucos caracteres.
        $short = $summary
        if ($short.Length -gt 60) { $short = $short.Substring(0, 60) }
        $notify.Text = $short
    }
    catch {
        $msg = $_.Exception.Message
        $statusItem.Text = "Erro ao consultar Codex"
        $notify.Text = "Codex: erro ao consultar limite"
    }
}

$refreshItem.add_Click({ Update-Usage })
$exitItem.add_Click({
    $timer.Stop()
    $notify.Visible = $false
    $notify.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

$notify.add_DoubleClick({ Update-Usage })

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $RefreshSeconds * 1000
$timer.add_Tick({ Update-Usage })
$timer.Start()

# Primeira leitura logo ao iniciar.
Update-Usage

Show-UsageNotification `
    -Title "Monitor do Codex iniciado" `
    -Text "O limite sera consultado localmente a cada 3 minutos. Clique duas vezes no icone para atualizar."

[System.Windows.Forms.Application]::Run()

$notify.Visible = $false
$notify.Dispose()
