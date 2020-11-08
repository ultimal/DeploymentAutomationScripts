Option Explicit

' This script is provided by Microsoft Corporation to demonstrate
' techniques that can be used to search, download, and install
' updates through the Windows Update Agent API. This script is
' not intended as production code.

' Supported parameters:
'    /AppName: Name to pass to the WUA API as the 'calling application';
'             this appears in the Windows Update logs
'             Default: "WUA API Sample Script"
'    /Criteria: Search criteria to be used (see the WUA documentation for
'             IUpdateSearcher::BeginSearch for examples)
'             Default: Search for all non-installed, non-hidden software
'    /Automate: Don't prompt the user for various actions
'             Default: Prompt the user
'    /IgnoreSupersedence: Display all applicable updates, even those
'             superseded by newer updates
'             Default: Ignore supersedes updates
'    /Offline: Path to WSUSSCN2.cab file that should be used for offline sync
'             Default: Don't do offline sync
'    /Service: Update service that script should scan against
'             Available values: WU, MU, WSUS, or an
'             identifying GUID of another service
'             Default: Default service (WSUS if machine is configured to
'                 use it, or MU if opted in, or WU otherwise)
'             Ignored if /Offline is set
'    /NoDownload: Do not download any updates that the scan detects
'    /NoInstall: Do not install any updates that the scan detects
'    /ShowBundle: Output information about the child updates in the 
'             bundled updates that are found

Function InstallationResultToText(result)
    Select Case result
        Case 2
            InstallationResultToText = "Succeeded"
        Case 3
            InstallationResultToText = "Succeeded with errors"
        Case 4
            InstallationResultToText = "Failed"
        Case 5
            InstallationResultToText = "Cancelled"
        Case Else
            InstallationResultToText = "Unexpected (" & result & ")"
    End Select
End Function

Function UpdateDescription(update)
    Dim description
    Dim I
    Dim category
    description = update.Title & " {" & update.Identity.UpdateID & "." & update.Identity.RevisionNumber & "}"
    if update.KBArticleIDs.Count > 0 Then
        description = description & " ("
        For I = 0 To update.KBArticleIDs.Count -1
            If I > 0 Then
                description = description & ","
            End If
            description = description & "KB" & update.KBArticleIDs.Item(I)
        Next
        description = description & ")"
    End If
    description = description & " Categories: "
    For I = 0 to update.Categories.Count - 1
        Set category = update.Categories.Item(I)
        If I > 0 Then
            description = description & ","
        End If
        description = description & category.Name & " {" & category.CategoryID & "}"
    Next  
    UpdateDescription = description
End Function

Dim appName
If WScript.Arguments.Named.Exists("AppName") Then
    appName = WScript.Arguments.Named.Item("AppName")
Else
    appName = "WUA API Sample Script"
End If

Dim criteria
If WScript.Arguments.Named.Exists("Criteria") Then
    criteria = WScript.Arguments.Named.Item("Criteria")
Else
    criteria = "IsInstalled=0 and Type='Software' and IsHidden=0"
End If

Dim isAutomated
isAutomated = WScript.Arguments.Named.Exists("Automate")

Dim ignoreSupersedence
ignoreSupersedence = WScript.Arguments.Named.Exists("IgnoreSupersedence")

Dim showBundle
showBundle = WScript.Arguments.Named.Exists("ShowBundle")

Dim serverSelection
Dim serviceId
serverSelection = 0
serviceId = ""

If WScript.Arguments.Named.Exists("Service") Then
    Select Case UCase(WScript.Arguments.Named.Item("Service"))
        Case "WU"
            serverSelection = 2
        Case "MU"
            serverSelection = 3
            serviceId = "7971f918-a847-4430-9279-4a52d1efe18d"
        Case "WSUS"
            serverSelection = 1
        Case Else
            serverSelection = 3
            serviceId = WScript.Arguments.Named.Item("Service")
    End Select
End If

Dim noDownload
noDownload = WScript.Arguments.Named.Exists("NoDownload")

Dim noInstall
noInstall = WScript.Arguments.Named.Exists("NoInstall")

Dim strInput
strInput = ""

Dim returnValue
returnValue = 0

Dim automaticUpdates
Dim updateSettings
Dim objWMIService
Dim colListOfServices
Dim objService

Dim secondInstallPass
secondInstallPass = false

Dim updateSession
Set updateSession = CreateObject("Microsoft.Update.Session")
updateSession.ClientApplicationID = appName

Dim updateServiceManager
Dim offlineService
If WScript.Arguments.Named.Exists("Offline") Then
    Set updateServiceManager = CreateObject("Microsoft.Update.ServiceManager")
    Set offlineService = updateServiceManager.AddScanPackageService(appName, WScript.Arguments.Named.Item("Offline"), 0)
    serverSelection = 3
    serviceId = offlineService.ServiceID
    WScript.Echo "Registered offline scan cab, service ID " & serviceId & vbCRLF
End If
    
Dim updateSearcher
Set updateSearcher = updateSession.CreateUpdateSearcher()
updateSearcher.ServerSelection = serverSelection
If serverSelection = 3 Then
    updateSearcher.ServiceId = serviceId
End If
If ignoreSupersedence Then
    updateSearcher.IncludePotentiallySupersededUpdates = true
End If

WScript.Echo "Searching for updates..." & vbCRLF

Dim searchResult
Set searchResult = updateSearcher.Search(criteria)

WScript.Echo "List of applicable items found on the machine:"

Dim I
Dim B
For I = 0 To searchResult.Updates.Count-1
    Set update = searchResult.Updates.Item(I)
    WScript.Echo I + 1 & "> " & UpdateDescription(update)
    If showBundle Then
        For B = 0 to update.BundledUpdates.Count-1
            WScript.Echo I+1 & "> " & B+1 & "> " & UpdateDescription(update.BundledUpdates.Item(B))
        Next
    End If
Next

Dim updatesToDownload
Set updatesToDownload = CreateObject("Microsoft.Update.UpdateColl")

If searchResult.Updates.Count = 0 Then
    WScript.Echo "There are no applicable updates."
Else
    WScript.Echo vbCRLF & "Creating collection of updates to download:"

    Dim update
    Dim description
    Dim addThisUpdate
    Dim atLeastOneAdded
    Dim propertyTest
    atLeastOneAdded = false
    Dim exclusiveAdded
    exclusiveAdded = false
    If noDownload Then
        WScript.Echo "Skipping downloads as requested."
    Else
        For I = 0 to searchResult.Updates.Count-1
            Set update = searchResult.Updates.Item(I)
            description = UpdateDescription(update)
            addThisUpdate = false
            If exclusiveAdded Then
                WScript.Echo I + 1 & "> skipping: " & description & _
                    " because an exclusive update has already been selected"
            Else
                propertyTest = false
                On Error Resume Next
                propertyTest = update.InstallationBehavior.CanRequestUserInput
                On Error GoTo 0
                If propertyTest = true Then
                    WScript.Echo I + 1 & "> skipping: " & description  & _
                    " because it requires user input"
                Else
                    propertyTest = true
                    On Error Resume Next
                    propertyTest = update.EulaAccepted
                    On Error GoTo 0
                    If propertyTest = false Then
                        If isAutomated Then
                            WScript.Echo I + 1 & "> skipping: " & description  & _
                            " because it has a license agreement that has not been accepted"
                        Else
                            WScript.Echo I + 1 & "> note: " & description  & _
                            " has a license agreement that must be accepted:"
                            WScript.Echo update.EulaText
                            WScript.Echo "Do you accept this license agreement? (Y/[N])"
                            strInput = WScript.StdIn.Readline
                            WScript.Echo 
                            If (strInput = "Y" or strInput = "y") Then
                                update.AcceptEula()
                                addThisUpdate = true
                            Else
                                WScript.Echo I + 1 & "> skipping: " & description  & _
                                " because the license agreement was declined"
                            End If
                        End If
                    Else
                        addThisUpdate = true
                    End If
                End If
                If addThisUpdate Then
                    propertyTest = 0
                    On Error Resume Next
                    propertyTest = update.InstallationBehavior.Impact
                    On Error GoTo 0
                    If propertyTest = 2 Then
                        If atLeastOneAdded Then
                            WScript.Echo I + 1 & "> skipping: " & description  & _
                            " because it is exclusive and other updates are being installed first"
                            addThisUpdate = false
                        End If
                    End If
                End If
                If addThisUpdate Then
                    If Not isAutomated Then
                        WScript.Echo I + 1 & "> : " & description  & _
                        " is applicable; do you want to install it? ([Y]/N)"
                        strInput = WScript.StdIn.Readline
                        WScript.Echo
                        If (strInput = "N" or strInput = "n") Then
                            WScript.Echo "Skipping update"
                            addThisUpdate = false
                       End If
                    End If
                End If
                If addThisUpdate Then
                    WScript.Echo I + 1 & "> adding: " & description  
                    updatesToDownload.Add(update)
                    atLeastOneAdded = true
                    On Error Resume Next
                    propertyTest = update.InstallationBehavior.Impact
                    On Error GoTo 0
                    If propertyTest = 2 Then
                        WScript.Echo "This update is exclusive; skipping remaining updates"
                        exclusiveAdded = true
                    End If
                End If
            End If
        Next
    End If
End If

Dim updatesToInstall
Set updatesToInstall = CreateObject("Microsoft.Update.UpdateColl")

Dim rebootMayBeRequired
rebootMayBeRequired = false

If updatesToDownload.Count > 0 Then
    WScript.Echo vbCRLF & "Downloading updates..."

    Dim downloader
    Set downloader = updateSession.CreateUpdateDownloader() 
    downloader.Updates = updatesToDownload
    downloader.Download()

    WScript.Echo vbCRLF & "Successfully downloaded updates:"

    For I = 0 To updatesToDownload.Count-1
        Set update = updatesToDownload.Item(I)
        If update.IsDownloaded = true Then
            WScript.Echo I + 1 & "> " & UpdateDescription(update) 
            updatesToInstall.Add(update) 
            propertyTest = 0
            On Error Resume Next
            propertyTest = update.InstallationBehavior.RebootBehavior
            On Error GoTo 0
            If propertyTest > 0 Then
                rebootMayBeRequired = true
            End If
        End If
    Next
End If

strInput = "N"
If noInstall Then
    WScript.Echo "Skipping install as requested."
Else
    If updatesToInstall.Count > 0 Then
        strInput = "Y"
        If rebootMayBeRequired = true Then
            WScript.Echo vbCRLF & "These updates may require a reboot."
        End If
        If Not isAutomated Then
            WScript.Echo  vbCRLF & "Would you like to install updates now? (Y/[N])"
            strInput = WScript.StdIn.Readline
            WScript.Echo 
        End If
    End If

    If (strInput = "Y" or strInput = "y") Then
        WScript.Echo "Installing updates..."
        Dim installer
        Set installer = updateSession.CreateUpdateInstaller()
        installer.Updates = updatesToInstall
        Dim installationResult
        Set installationResult = installer.Install()
 
        returnValue = 1
        'Output results of install
        WScript.Echo "Installation Result: " & _
        InstallationResultToText(installationResult.ResultCode) 
        WScript.Echo "Reboot Required: " & _ 
        installationResult.RebootRequired & vbCRLF 
        WScript.Echo "Listing of updates installed " & _
        "and individual installation results:" 
 
        For I = 0 to updatesToInstall.Count - 1
            WScript.Echo I + 1 & "> " & _
            UpdateDescription(updatesToInstall.Item(i)) & ": " & _
            InstallationResultToText(installationResult.GetUpdateResult(I).ResultCode) & _
            " HRESULT: " & installationResult.GetUpdateResult(I).HResult
			If installationResult.GetUpdateResult(I).HResult = -2145116147 Then
				WScript.Echo "An update needed additional downloaded content. Please rerun the script."
			End If
        Next
           
    End If
End If

WScript.Quit (returnValue)