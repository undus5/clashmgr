# Clash Manager CLI

Clash service management tool

Platform: Linux, Windows (PowerShell 7)

## Installation

1. Clone or download this project

2. [Optional, Recommended] Add project directory to system PATH
For Linux, you can create a symlink for `clashmgr` to your PATH.

3. [Optional] Run `clashmgr update` to update runtime files.

4. [Optional] Download config subscription from your service provider, if you have one:

    ```bash
    echo "https://subscription_url" > ./subscription.txt
    clashmgr get ./subscription.txt
    ```

    It will download config file alongside that txt with same basename, like `./subscription.yaml`.
    You can use this `clashmgr get sub.txt` to update your subscription in the future.

5. [Optional] Edit `config.yaml` in the runtime directory for tweaking basic configuration if needed.

## Running Service

Start clash service via `clashmgr start`.

For Linux, it will start in background normally.

For Windows, it can only start in foreground, there's two way to run clash service in background:

Method 1 [Recommanded]: Register clash as a system service using [NSSM](http://nssm.cc/)

```
nssm install ClashService
# Path: C:\clashmgr\clash-windows-amd64-v3.exe
# Startup directory: C:\clashmgr\runtime
# Arguments: -d C:\clashmgr\runtime
```

Method 2: Create a Powershell function to start clash service:

```powershell
# execute the follow command
Write-Output "function Clashmgr-Start { Start-Job -ScriptBlock { clashmgr start } }" >> $profile
# then reopen PowerShell window and run:
clashmgr-start
```

With this method, if you close the terminal window, clash service will be closed too, so it's not recommanded.

After launching the clash service, apply your config file to the clash service

```bash
clashmgr set ./subscription.yaml
```

Now you can access http://localhost:9090/ui via your browser to manage proxies.
