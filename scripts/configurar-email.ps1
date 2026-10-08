$ErrorActionPreference = 'Stop'
# Aplica somente verificação e SMTP a um realm existente, sem reimportar usuários.
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskConfig = @{}
Get-Content -LiteralPath (Join-Path $taskRoot '.env') -Encoding UTF8 | ForEach-Object {
    if ($_ -match '^([A-Z_]+)=(.*)$') { $taskConfig[$matches[1]] = $matches[2] }
}
foreach ($taskKey in @('KC_ADMIN_USER', 'KC_ADMIN_PASSWORD', 'SMTP_HOST', 'SMTP_PORT', 'SMTP_FROM')) {
    if (-not $taskConfig[$taskKey]) { throw "Configure $taskKey no .env antes de habilitar a verificação." }
}
$taskBase = 'http://localhost:' + $taskConfig['KC_PORT']
$taskAuth = Invoke-RestMethod -Method Post -Uri "$taskBase/realms/master/protocol/openid-connect/token" -Body @{
    grant_type = 'password'; client_id = 'admin-cli'
    username = $taskConfig['KC_ADMIN_USER']; password = $taskConfig['KC_ADMIN_PASSWORD']
}
$taskSmtp = @{
    host = $taskConfig['SMTP_HOST']; port = $taskConfig['SMTP_PORT']
    from = $taskConfig['SMTP_FROM']; fromDisplayName = $taskConfig['SMTP_FROM_NAME']
    auth = $taskConfig['SMTP_AUTH']; user = $taskConfig['SMTP_USER']
    password = $taskConfig['SMTP_PASSWORD']; starttls = $taskConfig['SMTP_STARTTLS']
    ssl = $taskConfig['SMTP_SSL']
}
$taskBody = @{ verifyEmail = $true; smtpServer = $taskSmtp } | ConvertTo-Json -Depth 4
Invoke-RestMethod -Method Put -Uri "$taskBase/admin/realms/enxoval" -Headers @{
    Authorization = 'Bearer ' + $taskAuth.access_token
} -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($taskBody)) | Out-Null
Write-Output 'Verificação de e-mail e SMTP aplicados ao realm enxoval. Usuários preservados.'
