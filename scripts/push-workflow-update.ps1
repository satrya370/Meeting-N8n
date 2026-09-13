$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$workflowPath = Join-Path $root 'workflows\meeting-notes-main-pipeline.json'
$credentialPath = 'D:\.agents\Micro SaaS\Credential_information.md'
$keyPath = 'D:\Downloads\n8n-server-key-jakarta.pem'

$workflow = Get-Content -Raw -Encoding UTF8 $workflowPath | ConvertFrom-Json
$payload = [ordered]@{
  name       = $workflow.name
  nodes      = @($workflow.nodes)
  connections = $workflow.connections
  settings   = $workflow.settings
  staticData = $workflow.staticData
  pinData    = $workflow.pinData
}
$payloadPath = [IO.Path]::GetTempFileName()
[IO.File]::WriteAllText($payloadPath, ($payload | ConvertTo-Json -Depth 100), [Text.UTF8Encoding]::new($false))

$credentialText = Get-Content -Raw -LiteralPath $credentialPath
$apiKey = [regex]::Match($credentialText, '(?im)^Api key N8n Aws Vps:\s*(\S+)').Groups[1].Value
if ([string]::IsNullOrWhiteSpace($apiKey)) { throw 'n8n API key not found' }

try {
  & scp -i $keyPath -o IdentitiesOnly=yes $payloadPath 'ubuntu@15.232.197.72:/tmp/meeting-workflow-update.json'
  $remote = "curl -fsS --max-time 30 -X PUT -H 'X-N8N-API-KEY: $apiKey' -H 'Content-Type: application/json' --data-binary @/tmp/meeting-workflow-update.json http://127.0.0.1:5678/api/v1/workflows/XscXJksppe3HR3tS; rm -f /tmp/meeting-workflow-update.json"
  & ssh -i $keyPath -o IdentitiesOnly=yes 'ubuntu@15.232.197.72' $remote
}
finally {
  Remove-Item -LiteralPath $payloadPath -Force -ErrorAction SilentlyContinue
}
