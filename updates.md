# Updates

Output from when applying Windows Updates to the Windows nodes in the AKS cluster:

```console
$ $podName = kubectl get pods -l app=windows-updates -o jsonpath="{.items[0].metadata.name}"
$ kubectl logs $podName
Checking for nuget provider is installed...
Checking for PSWindowsUpdate module...
Checking for Windows updates...
Updates available:

KBArticle Title                                                                                 

--------- -----                                                                                 

          Security Intelligence Update for Microsoft Defender Antivirus - KB2267602 (Version 1.441.193.0) - Current ...
          2025-11 Cumulative Update for Microsoft server operating system version 21H2 for x64-based Systems (KB5068...


Applying updates and restarting if necessary
VERBOSE: akswinos000000 (11/13/2025 2:20:36 PM): Connecting to Windows Update server. Please wait...
VERBOSE: Found [2] Updates in pre search criteria
VERBOSE: Found [2] Updates in post search criteria

VERBOSE: Accepted [2] Updates ready to Download
X ComputerName   Result     KB        Size Title                                                

- ------------   ------     --        ---- -----                                                

1 akswinos000000 Accepted   KB2267602  2GB Security Intelligence Update for Microsoft Defender Antivirus - KB2267602...
1 akswinos000000 Accepted   KB5068787 25GB 2025-11 Cumulative Update for Microsoft server operating system version 2...
2 akswinos000000 Downloaded KB2267602  2GB Security Intelligence Update for Microsoft Defender Antivirus - KB2267602...
2 akswinos000000 Downloaded KB5068787 25GB 2025-11 Cumulative Update for Microsoft server operating system version 2...
VERBOSE: Downloaded [2] Updates ready to Install
3 akswinos000000 Installed  KB2267602  2GB Security Intelligence Update for Microsoft Defender Antivirus - KB2267602...
3 akswinos000000 Installed  KB5068787 25GB 2025-11 Cumulative Update for Microsoft server operating system version 2...
VERBOSE: Installed [2] Updates
VERBOSE: cmd /C shutdown -f -r -t 5
```