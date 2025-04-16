# https://hub.docker.com/_/microsoft-windows-servercore-iis
# https://mcr.microsoft.com/v2/windows/servercore/iis/tags/list
FROM mcr.microsoft.com/windows/servercore/iis:20250408-windowsservercore-ltsc2022

RUN powershell -NoProfile -Command Remove-Item -Recurse C:\inetpub\wwwroot\*

WORKDIR /inetpub/wwwroot

COPY index.html .
