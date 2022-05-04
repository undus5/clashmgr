# Clashc

Clash command-line management tool

Platform: Linux, Windows (require PowerShell 7)

## Installation

1. Clone or download this project

2. [Optional, Recommended] Add project directory to system PATH
For Linux, you can create a symlink for clashc.sh to your PATH.

3. Run `clashc update` to initialize clash, it will download clash program and it's dependencies into a runtime directory.
For Linux, it's in `~/.config/clash`.
For Windows, it's in `C:\ClashcRuntime`.
You can use this command to update all stuff in the future.

4. [Optional] Download config subscription from your service provider, if you have one

    ```bash
    echo "https://subscription_url" > ./subscription.txt
    clashc get ./subscription.txt
    ```

    It will download config file alongside that txt with same basename, like `./subscription.yaml`.
    You can use this `clashc get sub.txt` to update your subscription in the future.

5. [Optional] Edit `config.yaml` in the runtime directory to tweak basic configuration if needed.

## Running Service

Start service via `clashc start`.
For linux, it will start in background normally
For powershell, it can only start in foreground, so we need do some extra work:

```powershell
# method one
Start-Job -ScriptBlock { clashc start }

# method two
Write-Output "function Clashc-Start { Start-Job -ScriptBlock { clashc start } }" >> $profile
# then close and reopen powershell
clashc-start
```

With these two methods, you are still not allowed to close the terminal window after starting, so it's not recommanded.

The recommanded way is register clash as a system service using [NSSM](http://nssm.cc/)

```
nssm install Clashc
# Path: C:\ClashcRuntime\clash-windows-amd64-v3.exe
# Startup directory: C:\ClashcRuntime
# Arguments: -d C:\ClashcRuntime
```

Apply config file to clash service

```bash
clashc set ./subscription.yaml
```

Now you can access http://localhost:9090/ui through your browser to manage proxies via clash-dashboard and use the service
