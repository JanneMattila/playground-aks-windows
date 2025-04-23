# https://hub.docker.com/_/microsoft-windows-servercore-iis
# https://mcr.microsoft.com/v2/windows/servercore/iis/tags/list
FROM mcr.microsoft.com/windows/servercore/iis:20250408-windowsservercore-ltsc2022

RUN powershell -Command $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; \
  $DOTNET_HOSTING_VERSION = '9.0.4'; \
  Write-Host Installing .NET Hosting Bundle version: $DOTNET_HOSTING_VERSION; \
  Invoke-WebRequest https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/$DOTNET_HOSTING_VERSION/dotnet-hosting-$DOTNET_HOSTING_VERSION-win.exe -OutFile dotnet-hosting.exe; \
  Start-Process dotnet-hosting.exe -Wait -ArgumentList /quiet; \
  Remove-Item dotnet-hosting.exe -Force; \
  Write-Host Installation of .NET Hosting Bundle completed;

RUN powershell -Command $ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; \
  $APPLICATION_VERSION = 'v1.0.2'; \
  Write-Host Installing WebApp Network Tester version: $APPLICATION_VERSION; \
  Invoke-WebRequest https://github.com/JanneMattila/webapp-network-tester/releases/download/$APPLICATION_VERSION/webappnetworktester.zip -OutFile webapp-network-tester.zip; \
  Expand-Archive webapp-network-tester.zip; \
  Remove-Item webapp-network-tester.zip -Force; \
  Remove-Item C:/inetpub/wwwroot/* -Recurse -Force; \
  Copy-Item -Path webapp-network-tester/artifacts/webappnetworktester/* -Destination C:/inetpub/wwwroot/ -Recurse -Force; \
  Remove-Item webapp-network-tester -Recurse -Force; \
  Write-Host Installation of WebApp Network Tester completed;
