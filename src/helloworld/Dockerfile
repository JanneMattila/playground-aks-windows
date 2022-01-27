# https://hub.docker.com/_/microsoft-windows-servercore
FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Uses dism.exe to install the IIS role.
RUN dism.exe /online /enable-feature /all /featurename:iis-webserver /NoRestart

COPY index.html c:/inetpub/wwwroot

CMD [ "cmd" ]
