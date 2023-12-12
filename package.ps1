#!/usr/bin/env pwsh
#
#  Copyright 2023, Roger Brown
#
#  This file is part of rhubarb pi.
#
#  This program is free software: you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation, either version 3 of the License, or (at your
#  option) any later version.
# 
#  This program is distributed in the hope that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
#  more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>
#
# $Id: package.ps1 288 2023-12-12 16:46:00Z rhubarb-geek-nz $
#

$NUGET_VERSION = "6.8.0"
$URL = "https://dist.nuget.org/win-x86-commandline/v$NUGET_VERSION/nuget.exe"
$SHA256 = "6C9E1B09F06971933B08080E7272A2CA5B0D8222500744DA757BD8D019013A3D"

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

trap
{
	throw $PSItem
}

If(!(test-path "nuget.exe"))
{
	Write-Host "$URL"

	Invoke-WebRequest -Uri "$URL" -OutFile "nuget.exe"
}

if ((Get-FileHash -LiteralPath 'nuget.exe' -Algorithm "SHA256").Hash -ne $SHA256)
{
	throw "SHA256 mismatch for nuget.exe"
}

@'
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product Id="*" Name="NuGet" Language="1033" Version="6.8.0.131" Manufacturer="Microsoft Corporation" UpgradeCode="057FE491-FBF5-4985-A36F-245821C978CF">
    <Package InstallerVersion="200" Compressed="yes" InstallScope="perMachine" Platform="x86" Description="NuGet 6.8.0" Comments="NuGet 6.8.0" />
    <MediaTemplate EmbedCab="yes" />
    <Feature Id="ProductFeature" Title="setup" Level="1">
      <ComponentGroupRef Id="ProductComponents" />
    </Feature>
    <Upgrade Id="{057FE491-FBF5-4985-A36F-245821C978CF}">
      <UpgradeVersion Maximum="6.8.0.131" Property="OLDPRODUCTFOUND" OnlyDetect="no" IncludeMinimum="yes" IncludeMaximum="no" />
    </Upgrade>
    <InstallExecuteSequence>
      <RemoveExistingProducts After="InstallInitialize" />
      <WriteEnvironmentStrings/>
    </InstallExecuteSequence>
    <DirectoryRef Id="INSTALLDIR">
      <Component Id ="setEnviroment" Guid="{057FE491-FBF5-4985-A36F-245821C978CF}">
        <CreateFolder />
        <Environment Id="PATH" Action="set" Name="PATH" Part="last" Permanent="no" System="yes" Value="[INSTALLDIR]" />
       </Component>
    </DirectoryRef>
    <Feature Id="PathFeature" Title="PATH" Level="1" Absent="disallow" AllowAdvertise="no" Display="hidden" >
      <ComponentRef Id="setEnviroment"/>
      <ComponentRef Id="nuget.exe" />
    </Feature>
  </Product>
  <Fragment>
    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="ProgramFilesFolder">
        <Directory Id="PRODUCTDIR" Name="NuGet">
          <Directory Id="INSTALLDIR" Name="bin"/>
        </Directory>
      </Directory>
    </Directory>
  </Fragment>
  <Fragment>
    <ComponentGroup Id="ProductComponents">
      <Component Id="nuget.exe" Guid="*" Directory="INSTALLDIR">
        <File Id="nuget.exe" KeyPath="yes" Source="nuget.exe" />
      </Component>
    </ComponentGroup>
  </Fragment>
</Wix>
'@ | Set-Content -Path "NuGet.wxs"

& "$ENV:WIX/bin/candle.exe" -nologo "NuGet.wxs" -ext WixUtilExtension 

If ( $LastExitCode -ne 0 )
{
	Exit $LastExitCode
}

& "$ENV:WIX/bin/light.exe" -sw1076 -nologo -cultures:null -out "NuGet-$NUGET_VERSION-win-x86.msi" "NuGet.wixobj" -ext WixUtilExtension

If ( $LastExitCode -ne 0 )
{
	Exit $LastExitCode
}

$codeSignCertificate = Get-ChildItem -path Cert:\ -Recurse -CodeSigningCert | Where-Object {$_.Thumbprint -eq '601A8B683F791E51F647D34AD102C38DA4DDB65F'}

if ( -not $codeSignCertificate )
{
	throw 'Codesign certificate not found'
}

Set-AuthenticodeSignature -Certificate $codeSignCertificate -TimestampServer 'http://timestamp.digicert.com' -HashAlgorithm SHA256 -FilePath "NuGet-$NUGET_VERSION-win-x86.msi"
