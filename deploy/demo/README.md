# Windows Container Deployments in AKS

This folder contains two different deployment configurations for Windows containers in AKS, each serving different purposes.

## Deployment Comparison

| Feature           | Standard Container (`deployment.yaml`)      | HostProcess Container (`hostprocess-debug.yaml`) |
| ----------------- | ------------------------------------------- | ------------------------------------------------ |
| **Isolation**     | Process-isolated from the host              | Runs directly on the Windows host                |
| **Kernel Access** | No kernel access                            | Full kernel access                               |
| **User Context**  | `ContainerAdministrator` (container admin)  | `NT AUTHORITY\SYSTEM` (host SYSTEM account)      |
| **File System**   | Isolated container file system              | Host's file system                               |
| **Network**       | Container network namespace                 | Host network (`hostNetwork: true`)               |
| **UAC Prompts**   | Still subject to container UAC restrictions | No UAC - runs with highest privileges            |
| **Use Case**      | Running applications                        | Debugging, monitoring, node configuration        |
| **Security Risk** | Lower - contained environment               | Higher - full host access                        |

## When to Use Each

### Standard Container (`deployment.yaml`)

Use for **running applications** in a secure, isolated environment:

- Web applications (IIS, ASP.NET)
- Background services
- Any workload that doesn't require host-level access
- Production workloads

```yaml
securityContext:
  windowsOptions:
    runAsUserName: "ContainerAdministrator"
```

### HostProcess Container (`hostprocess-debug.yaml`)

Use for **debugging and diagnostics** that require kernel/host access:

- Running Sysinternals tools (Procmon, ProcDump, Handle, etc.)
- Node-level monitoring and troubleshooting
- Installing drivers or host-level components
- Accessing host file system and registry

```yaml
securityContext:
  windowsOptions:
    hostProcess: true
    runAsUserName: "NT AUTHORITY\\SYSTEM"
hostNetwork: true
```

## Running Procmon Example

### Why Procmon Doesn't Work in Standard Containers

Procmon requires:
1. Kernel-level access to monitor system calls
2. Loading a filter driver
3. Elevated privileges without UAC restrictions

Standard Windows containers, even with `ContainerAdministrator`, cannot:
- Load kernel drivers
- Access the host kernel
- Bypass container isolation

### Running Procmon in HostProcess Container

```powershell
# Deploy the HostProcess container
kubectl apply -f deploy/demo/hostprocess-debug.yaml

# Get the pod name
$debug_pod = (kubectl get pod -n demo -l app=windows-debug -o name | Select-Object -First 1)

# Connect to the container
kubectl exec --stdin --tty $debug_pod -n demo -- cmd

# Inside the container (which is actually on the host):
mkdir C:\Temp
curl https://live.sysinternals.com/Procmon.exe -o C:\Temp\Procmon.exe

# Start Procmon
C:\Temp\Procmon.exe /accepteula /Minimized /BackingFile C:\Temp\procmonlog.pml

# Generate activity, then stop
C:\Temp\Procmon.exe /Terminate

# Convert and view results
C:\Temp\Procmon.exe /OpenLog C:\Temp\procmonlog.pml /SaveAs C:\Temp\procmonlog.csv
type C:\Temp\procmonlog.csv | more
```

### Running pagefile commands

```powershell
# Deploy the HostProcess container
kubectl apply -f deploy/demo/hostprocess-debug.yaml

# Get the pod name
$debug_pod = (kubectl get pod -n demo -l app=windows-debug -o name | Select-Object -First 1)

# Connect to the container
kubectl exec --stdin --tty $debug_pod -n demo -- powershell

# Inside the container (which is actually on the host):

# Is it system-managed, and what's the commit limit?
Get-CimInstance Win32_ComputerSystem | Select-Object AutomaticManagedPagefile
Get-CimInstance Win32_OperatingSystem | Select-Object TotalVirtualMemorySize, FreeVirtualMemory, SizeStoredInPagingFiles

# Configured min/max (0/0 == system managed)
Get-CimInstance Win32_PageFileSetting | Select-Object Name, InitialSize, MaximumSize

# Actual current allocation and peak usage
Get-CimInstance Win32_PageFileUsage | Select-Object Name, AllocatedBaseSize, CurrentUsage, PeakUsage

# Commit limit vs commit charge (the numbers that matter for OOM headroom)
Get-Counter '\Memory\Commit Limit','\Memory\Committed Bytes','\Memory\% Committed Bytes In Use'
```

```console
PS C:\hpc> Get-CimInstance Win32_ComputerSystem | Select-Object AutomaticManagedPagefile

AutomaticManagedPagefile
------------------------
                   False


PS C:\hpc> Get-CimInstance Win32_OperatingSystem | Select-Object TotalVirtualMemorySize, FreeVirtualMemory, SizeStoredInPagingFiles

TotalVirtualMemorySize FreeVirtualMemory SizeStoredInPagingFiles
---------------------- ----------------- -----------------------
              38791932          34109028                 5242880


PS C:\hpc> Get-CimInstance Win32_PageFileSetting | Select-Object Name, InitialSize, MaximumSize

Name            InitialSize MaximumSize
----            ----------- -----------
C:\pagefile.sys        8096        8096


PS C:\hpc> Get-CimInstance Win32_PageFileUsage | Select-Object Name, AllocatedBaseSize, CurrentUsage, PeakUsage

Name            AllocatedBaseSize CurrentUsage PeakUsage
----            ----------------- ------------ ---------
C:\pagefile.sys              5120            0         0


PS C:\hpc> Get-Counter '\Memory\Commit Limit','\Memory\Committed Bytes','\Memory\% Committed Bytes In Use'

Timestamp                  CounterSamples
---------                  --------------
6/25/2026 1:24:39 PM       \\akswin25000003\memory\commit limit :
                           39722938368

                           \\akswin25000003\memory\committed bytes :
                           4795633664

                           \\akswin25000003\memory\% committed bytes in use :
                           12.0727062486281
```

## Security Considerations

| Aspect              | Standard Container    | HostProcess Container       |
| ------------------- | --------------------- | --------------------------- |
| **Attack Surface**  | Limited to container  | Full host access            |
| **Recommended For** | Production workloads  | Debugging/admin only        |
| **RBAC**            | Standard pod security | Requires elevated RBAC      |
| **Audit**           | Container-level       | Host-level (more sensitive) |

> ⚠️ **Warning**: HostProcess containers have full access to the Windows host. Use them only for debugging, troubleshooting, or administrative tasks. Never run untrusted workloads as HostProcess containers.

## References

- [HostProcess Containers Documentation](https://learn.microsoft.com/en-us/azure/aks/use-windows-hpc)
- [Windows Container Security](https://learn.microsoft.com/en-us/virtualization/windowscontainers/manage-containers/container-security)
- [Sysinternals Procmon](https://learn.microsoft.com/en-us/sysinternals/downloads/procmon)
