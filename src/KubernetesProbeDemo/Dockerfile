# Windows Server 2022 (IIS) deployment image for KubernetesProbeDemo
# https://hub.docker.com/_/microsoft-windows-servercore-iis
# https://mcr.microsoft.com/v2/windows/servercore/iis/tags/list

FROM mcr.microsoft.com/windows/servercore/iis:20250408-windowsservercore-ltsc2022

# Install the ASP.NET Core .NET Hosting Bundle so the app can run in-process under IIS
RUN powershell -Command $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; \
  $DOTNET_HOSTING_VERSION = '10.0.9'; \
  Write-Host Installing .NET Hosting Bundle version: $DOTNET_HOSTING_VERSION; \
  Invoke-WebRequest https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/$DOTNET_HOSTING_VERSION/dotnet-hosting-$DOTNET_HOSTING_VERSION-win.exe -OutFile dotnet-hosting.exe; \
  Start-Process dotnet-hosting.exe -Wait -ArgumentList /quiet; \
  Remove-Item dotnet-hosting.exe -Force; \
  Write-Host Installation of .NET Hosting Bundle completed;

# Deploy the published application from the GitHub release into the IIS web root.
# The kubernetesprobedemo.zip asset is produced by .github/workflows/release.yml.
RUN powershell -Command $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; \
  $APPLICATION_VERSION = 'v1.0.1'; \
  Write-Host Installing KubernetesProbeDemo version: $APPLICATION_VERSION; \
  Invoke-WebRequest https://github.com/JanneMattila/KubernetesProbeDemo/releases/download/$APPLICATION_VERSION/kubernetesprobedemo.zip -OutFile kubernetesprobedemo.zip; \
  Expand-Archive kubernetesprobedemo.zip -DestinationPath kubernetesprobedemo; \
  Remove-Item kubernetesprobedemo.zip -Force; \
  Remove-Item C:/inetpub/wwwroot/* -Recurse -Force; \
  Copy-Item -Path kubernetesprobedemo/* -Destination C:/inetpub/wwwroot/ -Recurse -Force; \
  Remove-Item kubernetesprobedemo -Recurse -Force; \
  Write-Host Installation of KubernetesProbeDemo completed;

# IIS serves the application on port 80
EXPOSE 80
