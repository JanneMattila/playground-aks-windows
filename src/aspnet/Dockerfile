# Depending on the operating system of the host machines(s) that will build or run the containers, the image specified in the FROM statement may need to be changed.
# For more information, please see https://aka.ms/containercompat
FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2019 AS build
WORKDIR /app

# copy csproj and restore as distinct layers
COPY *.sln .
COPY WebApp/*.csproj ./WebApp/

#RUN Invoke-WebRequest https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile /app/nuget.exe
#RUN nuget.exe restore

# copy src/everything else and build app
COPY WebApp/. ./WebApp/
WORKDIR /app/WebApp
RUN msbuild /p:Configuration=Release

FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2019 AS base
WORKDIR /inetpub/wwwroot
COPY --from=Build /app/WebApp/. ./
