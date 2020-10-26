If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))

{   
$arguments = "& '" + $myinvocation.mycommand.definition + "'"
Start-Process powershell -Verb runAs -ArgumentList $arguments
exit
}

Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force -Confirm:$false

$tryPowerCLI = Get-Command -Module VMWare.PowerCLI

if ($tryPowerCLI -eq $False)
{

    Install-Module -Name VMWare.PowerCLI -AllowClobber -Confirm:$false

    Get-Command -Module VMWare.PowerCLI

    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
}

$Login = Get-Credential

Connect-VIServer -Server 172.16.10.6 -Credential $Login -ErrorAction Stop

Clear-Host

function Menu {

    do {

        Write-Host " "
        Write-Host "        #################################"
        Write-Host "        #                               #"
        Write-Host "        #     1. Opret VM               #"
        Write-Host "        #     2. Opret Gruppe           #"
        Write-Host "        #     3. Fjern Gruppe           #"
        Write-Host "        #                               #"
        Write-Host "        #     Q. Lukker Menu            #"
        Write-Host "        #                               #"
        Write-Host "        #################################"
        Write-Host " "

        $choice = Read-Host "        Indtast valg"
        Write-Host ""
        $ok = @("1", "2", "3", "q") -contains $choice

        if (-not $ok) {Write-Host "Forkert Valg"}

        switch ($choice) {
            "1" {
            OpretVM
            }
            "2"  {
            OpretGruppe
            }
            "3" {
            Slet
            }
        }

    } until ($choice -eq 'q')
}

function OpretVM {

    $VMHost = Read-Host "Indtast VM Host (Fysiske Maskine)"
    $VMNavn = Read-Host "Indtast navn på VM"
    $VMDisk = Read-Host "Indtast diskplads til VM"
    $VMCpu = Read-Host "Indtast antal processorer"
    $VMMemory = Read-Host "Indtast antal GB Ram"
    $VMDatastore = Read-Host "Indtast Datastore (LUN)"
    $VMNetwork = Read-Host "Indtast VLAN"
    $VMFolder = Read-Host "Indtast mappe hvor VM skal være"

    $VMDatastore = $VMDatastore + "-LUN"

    # Vi finder lige ud af hvilket Vlan det er.
    if ($VMNetwork -ge 100) {
    $VMNetwork = "PG-VLAN-" + $VMNetwork
    } else {
    $VMNetwork = "Vlan " + $VMNetwork
    }

    if ($VMFolder -eq 'Servere') {
    $VMFolder = "1 - " + $VMFolder
    }
    if ($VMFolder -eq 'Sandkasser') {
    $VMFolder = "2 - " + $VMFolder
    }
    if ($VMFolder -eq 'Templates') {
    $VMFolder = "3 - " + $VMFolder
    }

    New-VM -Name $VMNavn -VMHost $VMHost -DiskGB $VMDisk -NumCpu $VMCpu -MemoryGB $VMMemory -Datastore $VMDatastore -NetworkName $VMNetwork -Location $VMFolder
    sleep 2
    Clear-Host
    
}

function OpretGruppe {

    $VMGruppe = Read-Host "Hvilken gruppe? F.eks. (Gruppe-01)"

    Write-Host "----------- { KLIENTER } -----------"
    # Dette er navnene til klienterne
    $VMNavnKlient01 = Read-Host "Indtast navn på Klient VM (1)"
    $VMNavnKlient02 = Read-Host "Indtast navn på Klient VM (2)"

    Write-Host " "

    Write-Host "----------- { Servere } -----------"
    # Dette er navnene til Serverene
    $VMNavnServer01 = Read-Host "Indtast navn på Server VM (1)"
    $VMNavnServer02 = Read-Host "Indtast navn på Server VM (2)"

    Get-VMHost | Select-Object -Property Name
    $VMHost = Read-Host "Indtast VM Host (Fysiske Maskine)"
    $VMNetwork = Read-Host "Indtast VLAN F.eks. (PG-VLAN-101)"

    # Dette er til Klient oprettelse
    New-VM -Name $VMNavnKlient01 -Template 'TP Win10' -OSCustomizationSpec 'Windows Sandkasse' -VMHost $VMHost -Datastore "Sandkasse-LUN" -Location $VMGruppe
    New-VM -Name $VMNavnKlient02 -Template 'TP Win10' -OSCustomizationSpec 'Windows Sandkasse' -VMHost $VMHost -Datastore "Sandkasse-LUN" -Location $VMGruppe

    # Dette er til Server oprettelse
    New-VM -Name $VMNavnServer01 -Template 'TP Win2019' -OSCustomizationSpec 'Windows Sandkasse' -VMHost $VMHost -Datastore "Sandkasse-LUN" -Location $VMGruppe
    New-VM -Name $VMNavnServer02 -Template 'TP Win2019' -OSCustomizationSpec 'Windows Sandkasse' -VMHost $VMHost -Datastore "Sandkasse-LUN" -Location $VMGruppe

    Get-VM -Location $VMGruppe | Get-NetworkAdapter | where {"PG-VLAN-100" -eq "PG-VLAN-100"} | Set-NetworkAdapter -NetworkName $VMNetwork -confirm:$false

    pause

    sleep 2
    Clear-Host
}

function Slet {

    $VMGruppe = Read-Host "Hvilken Gruppe vil du slette? F.eks. (Gruppe-01)"
    Remove-Folder -Folder $VMGruppe -DeletePermanently
    New-Folder -Name $VMGruppe -Location "2 - Sandkasser"
    Get-Folder -Name $VMGruppe | New-VIPermission -Principal skpvejle.local\$VMGruppe -Role 'Virtual Machine Console User' -Propagate:$true
    sleep 2
    Clear-Host
}
Menu