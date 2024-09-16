# Переменные для имен ресурсов
$RG1 = "ResourceGroup1"
$RG2 = "ResourceGroup2"
$RG3 = "ResourceGroup3"

$VNET1_RG1 = "VNet1_RG1"
$VNET2_RG1 = "VNet2_RG1"

$VNET1_RG2 = "VNet1_RG2"
$VNET2_RG2 = "VNet2_RG2"

$VNET1_RG3 = "VNet1_RG3"

# Переменные для регионов
$LOCATION_RG1 = "eastus"
$LOCATION_RG2 = "westeurope"
$LOCATION_RG3 = "westus2"

# Функция для проверки существования ресурсной группы
function Test-ResourceGroupExists {
    param (
        [string]$ResourceGroupName
    )
    return (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue) -ne $null
}

# Функция для проверки существования виртуальной сети
function Test-VirtualNetworkExists {
    param (
        [string]$VNetName,
        [string]$ResourceGroupName
    )
    return (Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue) -ne $null
}

# Создание ресурсных групп, если они не существуют
if (-not (Test-ResourceGroupExists -ResourceGroupName $RG1)) {
    New-AzResourceGroup -Name $RG1 -Location $LOCATION_RG1
}

if (-not (Test-ResourceGroupExists -ResourceGroupName $RG2)) {
    New-AzResourceGroup -Name $RG2 -Location $LOCATION_RG2
}

if (-not (Test-ResourceGroupExists -ResourceGroupName $RG3)) {
    New-AzResourceGroup -Name $RG3 -Location $LOCATION_RG3
}

# Создание VNet в первой ресурсной группе (в регионе eastus)
if (-not (Test-VirtualNetworkExists -VNetName $VNET1_RG1 -ResourceGroupName $RG1)) {
    New-AzVirtualNetwork -ResourceGroupName $RG1 -Location $LOCATION_RG1 -Name $VNET1_RG1 -AddressPrefix "10.0.0.0/16"
}

if (-not (Test-VirtualNetworkExists -VNetName $VNET2_RG1 -ResourceGroupName $RG1)) {
    New-AzVirtualNetwork -ResourceGroupName $RG1 -Location $LOCATION_RG1 -Name $VNET2_RG1 -AddressPrefix "10.1.0.0/16"

    # Создание подсетей во втором VNet в первой ресурсной группе (в регионе eastus), только если VNet2_RG1 создана
    Add-AzVirtualNetworkSubnetConfig -Name "Subnet1" -AddressPrefix "10.1.1.0/24" -VirtualNetwork (Get-AzVirtualNetwork -ResourceGroupName $RG1 -Name $VNET2_RG1)
    Add-AzVirtualNetworkSubnetConfig -Name "Subnet2" -AddressPrefix "10.1.2.0/24" -VirtualNetwork (Get-AzVirtualNetwork -ResourceGroupName $RG1 -Name $VNET2_RG1) | Set-AzVirtualNetwork
}

# Создание VNet во второй ресурсной группе (в регионе westeurope)
if (-not (Test-VirtualNetworkExists -VNetName $VNET1_RG2 -ResourceGroupName $RG2)) {
    New-AzVirtualNetwork -ResourceGroupName $RG2 -Location $LOCATION_RG2 -Name $VNET1_RG2 -AddressPrefix "10.2.0.0/16"
}

if (-not (Test-VirtualNetworkExists -VNetName $VNET2_RG2 -ResourceGroupName $RG2)) {
    New-AzVirtualNetwork -ResourceGroupName $RG2 -Location $LOCATION_RG2 -Name $VNET2_RG2 -AddressPrefix "10.3.0.0/16"

    # Создание одной подсети во втором VNet во второй ресурсной группе (в регионе westeurope), только если VNet2_RG2 создана
    Add-AzVirtualNetworkSubnetConfig -Name "Subnet1" -AddressPrefix "10.3.1.0/24" -VirtualNetwork (Get-AzVirtualNetwork -ResourceGroupName $RG2 -Name $VNET2_RG2) | Set-AzVirtualNetwork
}

# Создание VNet в третьей ресурсной группе (в регионе westus2)
if (-not (Test-VirtualNetworkExists -VNetName $VNET1_RG3 -ResourceGroupName $RG3)) {
    New-AzVirtualNetwork -ResourceGroupName $RG3 -Location $LOCATION_RG3 -Name $VNET1_RG3 -AddressPrefix "10.4.0.0/16"
}

# Установка пирингов (Peering) между VNet, если они не созданы
function Test-VirtualNetworkPeeringExists {
    param (
        [string]$PeeringName,
        [string]$VNetName,
        [string]$ResourceGroupName
    )
    return (Get-AzVirtualNetworkPeering -Name $PeeringName -VirtualNetworkName $VNetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue) -ne $null
}

# Установка пирингов, если они не существуют
$vnet1_rg1 = Get-AzVirtualNetwork -Name $VNET1_RG1 -ResourceGroupName $RG1
$vnet2_rg1 = Get-AzVirtualNetwork -Name $VNET2_RG1 -ResourceGroupName $RG1
$vnet1_rg2 = Get-AzVirtualNetwork -Name $VNET1_RG2 -ResourceGroupName $RG2
$vnet2_rg2 = Get-AzVirtualNetwork -Name $VNET2_RG2 -ResourceGroupName $RG2
$vnet1_rg3 = Get-AzVirtualNetwork -Name $VNET1_RG3 -ResourceGroupName $RG3

# Список всех пировок, которые необходимо создать
$peerings = @(
    @{Name="Peering_VNet1_RG1_to_VNet2_RG1"; LocalVNet=$vnet1_rg1; RemoteVNet=$vnet2_rg1}
    @{Name="Peering_VNet2_RG1_to_VNet1_RG1"; LocalVNet=$vnet2_rg1; RemoteVNet=$vnet1_rg1}
    @{Name="Peering_VNet1_RG1_to_VNet1_RG2"; LocalVNet=$vnet1_rg1; RemoteVNet=$vnet1_rg2}
    @{Name="Peering_VNet1_RG2_to_VNet1_RG1"; LocalVNet=$vnet1_rg2; RemoteVNet=$vnet1_rg1}
    @{Name="Peering_VNet1_RG1_to_VNet2_RG2"; LocalVNet=$vnet1_rg1; RemoteVNet=$vnet2_rg2}
    @{Name="Peering_VNet2_RG2_to_VNet1_RG1"; LocalVNet=$vnet2_rg2; RemoteVNet=$vnet1_rg1}
    @{Name="Peering_VNet1_RG1_to_VNet1_RG3"; LocalVNet=$vnet1_rg1; RemoteVNet=$vnet1_rg3}
    @{Name="Peering_VNet1_RG3_to_VNet1_RG1"; LocalVNet=$vnet1_rg3; RemoteVNet=$vnet1_rg1}
    @{Name="Peering_VNet2_RG1_to_VNet1_RG2"; LocalVNet=$vnet2_rg1; RemoteVNet=$vnet1_rg2}
    @{Name="Peering_VNet1_RG2_to_VNet2_RG1"; LocalVNet=$vnet1_rg2; RemoteVNet=$vnet2_rg1}
    @{Name="Peering_VNet2_RG1_to_VNet2_RG2"; LocalVNet=$vnet2_rg1; RemoteVNet=$vnet2_rg2}
    @{Name="Peering_VNet2_RG2_to_VNet2_RG1"; LocalVNet=$vnet2_rg2; RemoteVNet=$vnet2_rg1}
    @{Name="Peering_VNet2_RG1_to_VNet1_RG3"; LocalVNet=$vnet2_rg1; RemoteVNet=$vnet1_rg3}
    @{Name="Peering_VNet1_RG3_to_VNet2_RG1"; LocalVNet=$vnet1_rg3; RemoteVNet=$vnet2_rg1}
    @{Name="Peering_VNet1_RG2_to_VNet2_RG2"; LocalVNet=$vnet1_rg2; RemoteVNet=$vnet2_rg2}
    @{Name="Peering_VNet2_RG2_to_VNet1_RG2"; LocalVNet=$vnet2_rg2; RemoteVNet=$vnet1_rg2}
    @{Name="Peering_VNet1_RG2_to_VNet1_RG3"; LocalVNet=$vnet1_rg2; RemoteVNet=$vnet1_rg3}
    @{Name="Peering_VNet1_RG3_to_VNet1_RG2"; LocalVNet=$vnet1_rg3; RemoteVNet=$vnet1_rg2}
    @{Name="Peering_VNet2_RG2_to_VNet1_RG3"; LocalVNet=$vnet2_rg2; RemoteVNet=$vnet1_rg3}
    @{Name="Peering_VNet1_RG3_to_VNet2_RG2"; LocalVNet=$vnet1_rg3; RemoteVNet=$vnet2_rg2}
)

foreach ($peering in $peerings) {
    if (-not (Test-VirtualNetworkPeeringExists -PeeringName $peering.Name -VNetName $peering.LocalVNet.Name -ResourceGroupName $peering.LocalVNet.ResourceGroupName)) {
        Add-AzVirtualNetworkPeering -Name $peering.Name -VirtualNetwork $peering.LocalVNet -RemoteVirtualNetworkId $peering.RemoteVNet.Id -AllowForwardedTraffic -AllowGatewayTransit -AllowVirtualNetworkAccess
    }
}
