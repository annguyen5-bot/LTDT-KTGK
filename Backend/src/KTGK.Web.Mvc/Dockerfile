FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

RUN dotnet tool install -g Microsoft.Web.LibraryManager.Cli
RUN ln -s ~/.dotnet/tools/libman /usr/local/bin/libman

WORKDIR /src
COPY ["src/KTGK.Web.Mvc/KTGK.Web.Mvc.csproj", "src/KTGK.Web.Mvc/"]
COPY ["src/KTGK.Web.Core/KTGK.Web.Core.csproj", "src/KTGK.Web.Core/"]
COPY ["src/KTGK.Application/KTGK.Application.csproj", "src/KTGK.Application/"]
COPY ["src/KTGK.Core/KTGK.Core.csproj", "src/KTGK.Core/"]
COPY ["src/KTGK.EntityFrameworkCore/KTGK.EntityFrameworkCore.csproj", "src/KTGK.EntityFrameworkCore/"]
WORKDIR "/src/src/KTGK.Web.Mvc"
RUN dotnet restore 

WORKDIR /src
COPY ["src/KTGK.Web.Mvc", "src/KTGK.Web.Mvc"]
COPY ["src/KTGK.Web.Core", "src/KTGK.Web.Core"]
COPY ["src/KTGK.Application", "src/KTGK.Application"]
COPY ["src/KTGK.Core", "src/KTGK.Core"]
COPY ["src/KTGK.EntityFrameworkCore", "src/KTGK.EntityFrameworkCore"]
WORKDIR "/src/src/KTGK.Web.Mvc"
RUN libman restore
RUN dotnet publish -c Release -o /publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0
EXPOSE 80
WORKDIR /app
COPY --from=build /publish .
ENTRYPOINT ["dotnet", "KTGK.Web.Mvc.dll"]
