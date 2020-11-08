
Function OnSite {
    param($Computer);
    
    if ((Get-CimInstance -ClassName Win32_PingStatus -Filter "Address='$Computer' and timeout=5000").StatusCode -eq 0)  { 
        "Connected" 
    } else { 
        "Not Connected"
    } 
}