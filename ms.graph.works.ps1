#
# Script.ps1
#
function GetAuthToken
{
	param
	(
		[Parameter(Mandatory=$true)]
		$clientId,
		[Parameter(Mandatory=$true)]
		$clientSecret,
		[Parameter(Mandatory=$false)]
		$tenant = "xxx.onmicrosoft.com"
	)
 
	$adal = "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
 
	[System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
 
	$resourceAppIdURI = "https://graph.microsoft.com"
	$authority = "https://login.microsoftonline.com/$tenant"
 
	$authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
	$creds = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential" -ArgumentList $clientId, $clientSecret
 
	$authResult = $authContext.AcquireToken($resourceAppIdURI, $creds)
 
	return $authResult
}

function GetGroups
{
	param
	(
		[Parameter(Mandatory=$true)]
		$clientId,
		[Parameter(Mandatory=$true)]
		$clientSecret,
		[Parameter(Mandatory=$false)]
		$tenant = "tlkenterprise.onmicrosoft.com"
	)

	$resourceAppIdURI = "https://graph.microsoft.com/v1.0"
	$resource = "groups"

 	$token = GetAuthToken -clientId $clientId -clientSecret $clientSecret -tenant $tenant

	# Building Rest Api header with authorization token
	$authHeader = @{
		'Content-Type'='application\json'
		'Authorization'=$token.CreateAuthorizationHeader()
	}

	$uri = "$resourceAppIdURI/$tenant/$($resource)"
	$groups = (Invoke-RestMethod -Uri $uri –Headers $authHeader –Method Get –Verbose).value
	
	return $groups
}

$groups = GetGroups -clientId "clientId" -clientSecret "clientSecret"

"ID                                    DisplayName"
foreach ($group in $groups)
{
	$group.id + "   " + $group.displayName
}
"---End---"
