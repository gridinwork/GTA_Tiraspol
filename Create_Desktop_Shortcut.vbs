Option Explicit
Dim shell, fs, folder, link
Set shell = CreateObject("WScript.Shell")
Set fs = CreateObject("Scripting.FileSystemObject")
folder = fs.GetParentFolderName(WScript.ScriptFullName)
If Not fs.FileExists(folder & "\GTA_Tiraspol.exe") Then
    MsgBox "Extract the entire game archive first. GTA_Tiraspol.exe must be beside this script.", 48, "GTA Tiraspol"
    WScript.Quit 1
End If
Set link = shell.CreateShortcut(shell.SpecialFolders("Desktop") & "\GTA Tiraspol.lnk")
link.TargetPath = folder & "\GTA_Tiraspol.exe"
link.WorkingDirectory = folder
link.IconLocation = folder & "\Touareg.ico,0"
link.Description = "GTA Tiraspol - Balka"
link.Save
MsgBox "Desktop shortcut created.", 64, "GTA Tiraspol"
