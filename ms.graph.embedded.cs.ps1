
$path = "E:\Work\packages"

[System.Reflection.Assembly]::LoadFrom("${env:ProgramFiles(x86)}\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.5\System.Net.Http.dll") | Out-Null
[System.Reflection.Assembly]::LoadFrom("${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\Microsoft.IdentityModel.Clients.ActiveDirectory.dll") | Out-Null
[System.Reflection.Assembly]::LoadFrom("$path\Microsoft.Graph.1.6.2\lib\net45\Microsoft.Graph.dll") | Out-Null

$Assem =@(
        "${env:ProgramFiles(x86)}\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.5\System.Net.Http.dll",
        "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\Microsoft.IdentityModel.Clients.ActiveDirectory.dll",
        "$path\Microsoft.Graph.Core.1.6.2\lib\net45\Microsoft.Graph.Core.dll",
		    "$path\Microsoft.Graph.1.6.2\lib\net45\Microsoft.Graph.dll",
		    "$path\Newtonsoft.Json.6.0.1\lib\net45\Newtonsoft.Json.dll"
         ) 

$Source = @"
		using Microsoft.Graph;
		using Microsoft.IdentityModel.Clients.ActiveDirectory;
		using System.Configuration;
		using System.Net.Http;
		using System.Threading.Tasks;

		namespace MicrosoftGraphWrapper
		{
			public class AzureAuthenticationProvider : IAuthenticationProvider
			{
				public Task AuthenticateRequestAsync(HttpRequestMessage request)
				{
					Task t = new Task(() =>
					{
						string clientId = "clientId";
						string clientSecret = "clientSecret";
						string authority = "https://login.microsoftonline.com/xxx.onmicrosoft.com";

						AuthenticationContext authContext = new AuthenticationContext(authority);

						ClientCredential creds = new ClientCredential(clientId, clientSecret);

						string accessToken = authContext.AcquireTokenAsync("https://graph.microsoft.com", creds).Result.AccessToken;

						request.Headers.Add("Authorization", "Bearer " + accessToken);
					});

					t.Start();
					return t;
				}
			}
		}
"@ 

Add-Type -ReferencedAssemblies $Assem -TypeDefinition $Source -Language CSharp

"ID                                    DisplayName"

$authProvider = New-Object MicrosoftGraphWrapper.AzureAuthenticationProvider
$graphClient = New-Object Microsoft.Graph.GraphServiceClient -ArgumentList $authProvider

$result = $graphClient.Groups.Request().OrderBy("displayName").GetAsync()
$groups = $result.Result;

if ($groups -ne $null -and $groups.Count -gt 0)
{
	foreach ($group in $groups)
	{
		$group.Id + "   " + $group.DisplayName
	}
}

"---End---"
