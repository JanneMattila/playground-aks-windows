# Depending on the operating system of the host machines(s) that will build or run the containers, the image specified in the FROM statement may need to be changed.
# For more information, please see https://aka.ms/containercompat
# https://hub.docker.com/_/microsoft-dotnet-framework-sdk/
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-20220111-windowsservercore-ltsc2019 AS build
WORKDIR /app

COPY *.sln .
COPY WebApp/*.csproj ./WebApp/
COPY WebApp/*.config ./WebApp/

RUN nuget restore

COPY WebApp/. ./WebApp/
RUN msbuild /p:Configuration=Release /p:DeployOnBuild=true /p:PublishProfile=FolderProfile.pubxml

# https://hub.docker.com/_/microsoft-dotnet-framework-aspnet/
FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-20220111-windowsservercore-ltsc2019 AS base
WORKDIR /inetpub/wwwroot
COPY --from=Build /app/WebApp/bin/app.publish/. ./
