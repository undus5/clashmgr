# clashc

clash command-line management tool

platform: Linux, Windows (need PowerShell 7)

## Usage

clone or download this project

[optional, recommended] add project directory to system path

run `clashc update` to initialize clash, it will download clash program and it's dependencies into `~/.config/clash`
you can use this command to update all stuff in the future

[optional] download config subscription from your service provider, if you have one
```bash
echo "https://subscription_url" > ./subscription.txt
clashc get ./subscription.txt
```
it will download config file alongside that txt with same basename, like ./subscription.yaml
you can use this `clashc get sub.txt` to update your subscription in the future

[optional] edit ~/.config/clash/config.yaml to tweak basic configuration if needed

start service via `clashc start`
for linux, it will start in background normally
for powershell, it can only start in foreground, we need do some extra work:
```powershell
# method one
Start-Job -ScriptBlock { clashc start }

# method two
Write-Output "function Clashc-Start { Start-Job -ScriptBlock { clashc start } }" >> $profile
# then close and reopen powershell
clashc-start
```

apply your own config to clash service
```bash
clashc set ./subscription.yaml
```

now you can access 127.0.0.1:9090/ui in your browser to manage proxies via clash-dashboard and use the service
