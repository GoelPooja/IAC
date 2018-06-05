Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install gittfs -y
Read-Host -Prompt "Press Enter to exit"