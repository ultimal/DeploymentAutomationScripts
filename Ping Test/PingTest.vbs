' *****************************************************************************
'   NAME:           Ping Test Utility
'   DESCRIPTION:    Sets a Task Sequence variable if a host can be pinged.
'   
'   DEVELOPER:      Haider Raza
'   DATE:           08-11-2020
'   
'   Copyright 2020 QuickPoint Inc.
'
'   This file is part of Deployment Automation Scripts.
'
'   Deployment Automation Scripts are free software; you can redistribute it 
'   and/or modify it under the terms of the GNU General Public License as 
'   published by the Free Software Foundation; either version 3 of the License,
'   or (at your option) any later version.
'
'   GNU tar is distributed in the hope that it will be useful,
'   but WITHOUT ANY WARRANTY; without even the implied warranty of
'   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
'   GNU General Public License for more details.
'
'   You should have received a copy of the GNU General Public License
'   along with this program.  If not, see <http://www.gnu.org/licenses/>.
'
' *****************************************************************************

' Must declare all variables
Option Explicit

' Get all arguments
Dim args: Set args = WScript.Arguments
Dim computerName

    ' This function returns True if the specified host could be pinged.
    ' myHostName can be a computer name or IP address.
    ' The Win32_PingStatus class used in this function requires Windows XP or later.
    ' This function is based on the TestPing function in a sample script by Don Jones
    ' http://www.scriptinganswers.com/vault/computer%20management/default.asp#activedirectoryquickworkstationinventorytxt
    Function Ping( myHostName )
        ' Standard housekeeping
        Dim colPingResults, objPingResult, strQuery

        ' Define the WMI query
        strQuery = "SELECT * FROM Win32_PingStatus WHERE Address = '" & myHostName & "'"

        ' Run the WMI query
        Set colPingResults = GetObject("winmgmts://./root/cimv2").ExecQuery( strQuery )

        ' Translate the query results to either True or False
        For Each objPingResult In colPingResults
            If Not IsObject( objPingResult ) Then
                Ping = False
            ElseIf objPingResult.StatusCode = 0 Then
                Ping = "True"
            Else
                Ping = "False"
            End If
        Next

        Set colPingResults = Nothing
    End Function

if WScript.Arguments.Count > 0 Then
    computerName = args(0)
    
    Dim env: set env = CreateObject("Microsoft.SMS.TSEnvironment") 
    env("PingResult") = Ping(computerName)
Else    
    WScript.Echo "*** USAGE: cscript.exe PingTest.vbs <computer_name>"
end if