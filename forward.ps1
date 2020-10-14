if (-Not($env:WSL_PORTS)) 
{
  Write-Error "No ports to forward"
  exit 1;
}

# get wsl distribution ip address
$remote_addr= bash.exe -c "ifconfig eth0 | grep 'inet '"
$local_addr='0.0.0.0';
$rule_name="WSL2 Forwarding";

if ($remote_addr -Match "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}") 
{
  $remote_addr = $matches[0];
  Write-Host "WSL remote address: $remote_addr"
} 
else 
{
  Write-Error "WSL remote address cannot be found"
  exit 1;
}

# get firewall rule list
$rules = Get-NetFirewallRule

# remove firewall exception rules
if ($rules.DisplayName.Contains($rule_name))
{
  Write-Host "Deletes firewall rule: $rule_name"
  Remove-NetFireWallRule -DisplayName $rule_name;
}

Write-Host "Creates outbound firewall rule: $rule_name"
New-NetFireWallRule `
  -DisplayName $rule_name `
  -Direction Outbound `
  -LocalPort $env:WSL_PORTS `
  -Action Allow `
  -Protocol TCP `
  | Out-Null

Write-Host "Creates inbound firewall rule: $rule_name"
New-NetFireWallRule `
  -DisplayName $rule_name `
  -Direction Inbound `
  -LocalPort $env:WSL_PORTS `
  -Action Allow `
  -Protocol TCP `
  | Out-Null

$env:WSL_PORTS -Split "," `
  | ForEach-Object `
  {
    Write-Host "Deletes port proxy: $_"
    netsh interface portproxy `
      delete v4tov4 `
      listenport=$_ `
      listenaddress=$local_addr `
      | Out-Null

    Write-Host "Creates port proxy: $_"
    netsh interface portproxy `
      add v4tov4 `
      listenport=$_ `
      listenaddress=$local_addr `
      connectport=$_ `
      connectaddress=$remote_addr `
      | Out-Null
  }
