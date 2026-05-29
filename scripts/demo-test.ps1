# Demo Test Script - Test all microservices endpoints
# Usage: .\scripts\demo-test.ps1 -EC2IP <IP>

param(
    [Parameter(Mandatory=$true)]
    [string]$EC2IP
)

$BaseURL = "http://$EC2IP:8080"

Write-Host "🚀 Starting Microservices Demo Test" -ForegroundColor Cyan
Write-Host "===================================="
Write-Host "Target: $BaseURL" -ForegroundColor Yellow
Write-Host ""

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Method,
        [string]$Endpoint,
        [string]$Data
    )

    Write-Host -NoNewline "Testing $Name... "

    try {
        if ([string]::IsNullOrEmpty($Data)) {
            $response = Invoke-WebRequest -Uri "$BaseURL$Endpoint" -Method $Method -ErrorAction Stop
        } else {
            $response = Invoke-WebRequest -Uri "$BaseURL$Endpoint" -Method $Method `
                -ContentType "application/json" -Body $Data -ErrorAction Stop
        }

        Write-Host "✓ $($response.StatusCode)" -ForegroundColor Green
        Write-Host "Response: $($response.Content | Select-String '.' | Select-Object -First 1)"
    } catch {
        Write-Host "✗ $($_.Exception.Response.StatusCode.Value)" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)"
    }
    Write-Host ""
}

# Health Checks
Write-Host "📊 Health Checks" -ForegroundColor Cyan
Write-Host "---------------"
Test-Endpoint "API Gateway Health" "GET" "/actuator/health"

# Detailed Health
Write-Host "📈 Detailed Health Status" -ForegroundColor Cyan
Write-Host "------------------------"
try {
    $health = Invoke-WebRequest -Uri "$BaseURL/actuator/health" -Method GET | ConvertFrom-Json
    $health | ConvertTo-Json | Write-Host
} catch {
    Write-Host "Could not retrieve health details" -ForegroundColor Red
}
Write-Host ""

Write-Host "✅ Demo Test Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "To check logs on EC2, SSH in and run:"
Write-Host "  docker compose -f /opt/app/docker-compose.yml logs -f" -ForegroundColor Yellow

