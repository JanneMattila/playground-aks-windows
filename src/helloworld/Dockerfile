# https://hub.docker.com/_/microsoft-windows-servercore-iis
FROM mcr.microsoft.com/windows/servercore/iis:20220119-windowsservercore-ltsc2022

RUN powershell -NoProfile -Command Remove-Item -Recurse C:\inetpub\wwwroot\*

WORKDIR /inetpub/wwwroot

COPY index.html .
