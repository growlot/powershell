Param(
    [Switch]$Backup,
    [Switch]$Restore,
    [string]$File = "C:\tmp\my-cert.pfx",
    [string]$Password = "test-password",
    [Switch]$RemainCertFile
    )

$BASE_REG_PATH = 'HKLM:\Software\Product'
$CUSTOMER_REGVALUE_NAME = 'CertificateThumbprint'

function OpenRegStore([bool]$ReadOnly)
{
    $CERT_STORE_PROV_REG = 4
    $X509_ASN_ENCODING = 0x00000001
    $PKCS_7_ASN_ENCODING = 0x00010000
    $MY_TYPE = $PKCS_7_ASN_ENCODING -bor $X509_ASN_ENCODING
    $CERT_STORE_READONLY_FLAG = 0x00008000

    $MethodDefinition = @"
        [DllImport("Crypt32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern IntPtr CertOpenStore(Int32 lpszStoreProvider,
            Int32 dwMsgAndCertEncodingType,
            IntPtr hCryptProv,
            Int32 dwFlags,
            IntPtr pvPara);
"@

    $Crypt32 = Add-Type -MemberDefinition $MethodDefinition -Name 'Crypt32' -Namespace 'Win32' -PassThru 

    $certStore = $null

    if (($registryKey = Get-Item ($BASE_REG_PATH + '\Certificates\My') -ErrorAction SilentlyContinue)) {
        $dwFlag = 0
        if ($ReadOnly) {
            $dwFlag = $CERT_STORE_READONLY_FLAG
        }
        $hStore = $Crypt32::CertOpenStore($CERT_STORE_PROV_REG, $MY_TYPE, 0, $dwFlag, $registryKey.Handle.DangerousGetHandle())
        $registryKey.Close()
        if (!$hStore) { return $null }
        $certStore = New-Object System.Security.Cryptography.X509Certificates.X509Store -ArgumentList $hStore
    } else {
        Write-Warning "Registry certificate store does not exist!"
    }

    return $certStore
}

function GetCustomerCertThumbprint([System.Security.Cryptography.X509Certificates.X509Store]$CertStore)
{
    if (!($baseKey = Get-Item -LiteralPath $BASE_REG_PATH)) { return $null }
    if (!($customerCertThumbprint = $baseKey.GetValue($CUSTOMER_REGVALUE_NAME, $null))) { return $null }
    if (!($certCollection = $CertStore.Certificates.Find("FindByThumbprint", $customerCertThumbprint, $false))) { return $null }
    if ($certCollection.Count -le 0) { return $null }
    return $certCollection[0]
}

function Backup([System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert, [string]$File, [string]$Password)
{
    Write-Host "Backing up..."
    Try
    {
        $dirPath = [System.IO.Path]::GetDirectoryName($File)
        if (!(Test-Path $dirPath)) { New-Item -path $dirPath -type directory }
        $data = $Cert.Export("Pfx", $Password)
        if (!$data -or ($data.Count -le 0)) {
            Write-Warning "Failed to backup!"
            return $false
        }
        [System.IO.File]::WriteAllBytes($File, $data)
    }
    Catch
    {
        $ErrorMessage = $_.Exception.Message
        Write-Warning "Failed to backup! The error message was $ErrorMessage."
        return $false
    }
    Write-Host "Backed up successfully!"
    return $true
}

function Restore([string]$File, [string]$Password, [System.Security.Cryptography.X509Certificates.X509Store]$CertStore)
{
    Write-Host "Restoring..."
    Try
    {
        if (!(Test-Path $File))  {
            Write-Warning "Failed to restore! $File does not exist."
            return $false
        }
        $data = [System.IO.File]::ReadAllBytes($File)
        if (!$data -or ($data.Count -le 0)) {
            Write-Warning "Failed to restore!"
            return $false
        }
        $CertStore.Certificates.Import($data, $Password, "Exportable")
    }
    Catch
    {
        $ErrorMessage = $_.Exception.Message
        Write-Warning "Failed to restore! The error message was $ErrorMessage."
        return $false
    }
    Write-Host "Restored successfully!"
    return $true
}

function DeleteCertFile([string]$File)
{
    Try
    {
        if (!(Test-Path $File))  {
            Write-Warning "$File does not exist."
            return $false
        }
        Remove-Item -Path $File -Force
    }
    Catch
    {
        $ErrorMessage = $_.Exception.Message
        Write-Warning "Failed to delete certificate file! The error message was $ErrorMessage."
        return $false
    }
    Write-Host "Deleted certificate file successfully!"
    return $true
}

$_mode = $true

if ($Restore) {
    $Backup = $false
} elseif (!$Backup) {
    $_mode = $false
}

$_readonly = $false
if ($_mode -or !$Backup) {
    $_readonly = $true
}

$_certStore = OpenRegStore -ReadOnly $_readonly

if (!$_certStore) {
    if ($_readonly) { Write-Warning "Could not open registry certificate store!" }
    else { Write-Warning "Could not open registry certificate store for saving!" }
    return $false
}

$_customerCert = GetCustomerCertThumbprint -CertStore $_certStore

if (!$_mode) {
    if ($_customerCert -and $_customerCert.HasPrivateKey) { $Backup = $true }
    else { $Restore = $true }
}
elseif ($Backup) {
    if (!$_customerCert -or !$_customerCert.HasPrivateKey) {
        Write-Warning "Could not get customer certificate or has not private key!"
        return $false
    }
}

if ($Restore -and $_readonly) {
    $_readonly = $false
    $_certStore = OpenRegStore -ReadOnly $_readonly
    if (!$_certStore) {
        if ($_readonly) { Write-Warning "Could not open registry certificate store!" }
        else { Write-Warning "Could not open registry certificate store for saving!" }
        return $false
    }
}

if ($Backup) { Backup -Cert $_customerCert -File $File -Password $Password }
elseif ($Restore) {
    Restore -File $File -Password $Password -CertStore $_certStore
    if (!$RemainCertFile) { DeleteCertFile -File $File }
}
else { Write-Warning "Nothing to do!" }
