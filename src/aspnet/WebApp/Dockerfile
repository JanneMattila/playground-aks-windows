FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2019 AS build
WORKDIR /app

# copy csproj and restore as distinct layers
COPY *.sln .
COPY WebApp/*.csproj ./WebApp/
COPY WebApp/*.config ./WebApp/
RUN nuget restore

# copy everything else and build app
COPY WebApp/. ./WebApp/
WORKDIR /app/WebApp
RUN msbuild /p:Configuration=Release

FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2019 AS base
WORKDIR /inetpub/wwwroot
COPY --from=Build /app/WebApp/. ./
