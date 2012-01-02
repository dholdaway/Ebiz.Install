function Security-DnnFix([string]$sitePath) {
	$path = join-path $sitePath "Website\Providers\HtmlEditorProviders\Fck"
	$config = join-path $sitePath "Website\web.config"

	if(!(Test-Path $path) -or !(test-path $config)) {
		Write-Warning "The path: $($path) or the website config file path: $($config) is not correct or does not exist."
		Exit
	}

	$guid = [guid]::NewGuid().ToString("n");

	get-childItem -Path $path -Recurse fcklinkgallery.*  | rename-item -newname { $_.name -replace 'fcklinkgallery', $guid }

	
	# backup the web.config
	cp $config "$config.bak"

	
	# Fix the web.config
	(Get-Content $config) | Foreach-Object {$_ -replace 'fcklinkgallery', $guid} | Set-Content $config
}

function Install-Ebiz {
	$ErrorActionPreference = "Stop"
		
	#Ensure we have the WebAdministration module loaded.
	Import-WebAdministration
	
	#Lets find out what the user wants to do
	Write-ColorText -Text "********************************************" -Color Green -NewLine
	Write-ColorText -Text "********************************************" -Color Green -NewLine
	Write-ColorText -Text "**                                        **" -Color Green -NewLine
	Write-ColorText -Text "**  What do you want to do?               **" -Color Green -NewLine
	Write-ColorText -Text "**                                        **" -Color Green -NewLine
	Write-ColorText -Text "**  1) Complete Ebiz Site Deployment      **" -Color Green -NewLine
	Write-ColorText -Text "**  2) Quit                               **" -Color Green -NewLine
	Write-ColorText -Text "**                                        **" -Color Green -NewLine
	Write-ColorText -Text "********************************************" -Color Green -NewLine
	Write-ColorText -Text "********************************************" -Color Green -NewLine
	$option = Read-Host "Your choice "
	
	While ($option -lt 1 -Or $option -gt 2) 
	{
		$option = Read-Host "Please choose a valid option: "
	}
	
	switch ($option) 
	{
		1 { 
			try {
				#Create site and App Pool
				$info = Install-Site -action $null -Internal
				
				
				#find Parent directory where Ebiz.Modules resides
				$dirs = $info["Path"].Split('\')
				$parentDir = $dirs[0]
				for($i=1; $i -lt $dirs.Length; $i++) {
					$parentDir = (Join-Path $parentDir $dirs[$i])
					if ((Test-Path (Join-Path $parentDir "Ebiz.Modules"))) {
						break
					}
				}
				
				#Create VirtualDirectories
				Write-ColorText -Text "Creating Virtual Directories..." -Color Cyan -NewLine
				Install-VirtualDirectory -site $info["Site"] -app $info["App"] -name "Services" -path (Join-Path $parentDir Ebiz.Modules\Services)
				
				Write-ColorText -Text "Select the Image directory...." -Color Cyan -NewLine
				$imageDir = Select-Folder -message "Please choose which directory contains Images." -path $info["Path"]
				
				Install-VirtualDirectory -site $info["Site"] -app $info["App"] -name "Images1" -path $imageDir
				Install-VirtualDirectory -site $info["Site"] -app $info["App"] -name "DesktopModules\Ebiz.Modules" -path (Join-Path $parentDir Ebiz.Modules)
				Install-VirtualDirectory -site $info["Site"] -app $info["App"] -name "DesktopModules\ModuleDefinitions" -path (Join-Path $parentDir Ebiz.Modules\ModuleDefinitions)
				
				#Create Handler Mappings
				Write-ColorText -Text "Creating Handler Mappings..." -Color Cyan -NewLine
				Install-HandlerMappings -site $info["Site"] -app $info["App"] -name "Ebiz WildCard Mapping" -path "*" -verb "*" -modules "IsapiModule" -scriptProcessor "%windir%\Microsoft.NET\Framework\v2.0.50727\aspnet_isapi.dll" -resourceType "Unspecified" -requireAccess "None"
				Install-HandlerMappings -site $info["Site"] -app $info["App"] -name "Image Mapping" -path "*.jpg, *.png, *.gif, *.ico, *.tif, *.tiff" -verb "GET" -modules "StaticFileModule" -resourceType "File" -requireAccess "Read"
			    Install-HandlerMappings -site $info["Site"] -app $info["App"] -name "Video Mapping" -path "*.avi, *.mp3, *.mp4, *.mpg, *.wmv" -verb "GET" -modules "StaticFileModule" -resourceType "File" -requireAccess "Read"
				Install-HandlerMappings -site $info["Site"] -app $info["App"] -name "Binary Mapping" -path "*.exe, *.zip, *.dfx" -verb "GET" -modules "StaticFileModule" -resourceType "File" -requireAccess "Read"
				Install-HandlerMappings -site $info["Site"] -app $info["App"] -name "Flash Mapping" -path "*.swf, *.fla, *.flv" -verb "GET" -modules "StaticFileModule" -resourceType "File" -requireAccess "Read"
				
				#apply Dnn Security Fix
				Write-ColorText -Text "Applying Dnn Security Fix" -Color Cyan -NewLine
				#Security-DnnFix -sitePath $info["Path"]
			}
			catch [Exception] {
				$_.Exception.ToString()
			}
		}
		2 { }
	}
}

Export-ModuleMember Install-Ebiz


#. $appcmd ADD VDIR /app.name:$site/ /path:/Services /physicalPath:$(Join-Path $site_path Ebiz.Modules\Services)
#. $appcmd ADD VDIR /app.name:$site/ /path:/Images1 /physicalPath:$(Join-Path $site_path Website\Portals\0\Skins\NationalProducts\images)
#. $appcmd ADD VDIR /app.name:$site/ /path:/DesktopModules/Ebiz.Modules /physicalPath:$(Join-Path $site_path Ebiz.Modules)
#. $appcmd ADD VDIR /app.name:$site/ /path:/DesktopModules/ModuleDefinitions /physicalPath:$(Join-Path $site_path Ebiz.Modules\ModuleDefinitions)
