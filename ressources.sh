
#########################################
NomDuGroupe=ara22
NomDuVnet=nomvnet
IpAddressVnet=10.0.0.0/16
NomDuSubnet=nomsubnet
IpAddressSubnet=10.0.0.0/24
NomIpPublic=monIPPublic
NomDuLb=monLBB
NomBackendPool=monBackendPool
NomIpBackend=monIPbackend
IpAddressBackend=ipadressBack
NomHealthProbe=monHP
NomVm=maVM
AdminName=adminvm
AdminPwd=Adminvmpass
PrivateIp=10.0.0.5
FrontendIpName=monIPfront
NomHTTPRule=moHTTPrule
NomNSG=monNSG
NomNSGRuleHTTP=monNSGruleHTTP
NomNic=monNic
NomNatGateway=monNATgate
NomMariadb=mdbg1b5database
NomAdminMDB=mdbg1admin1
Passadmin=Adminpass1
nbzone=3

######################################################
######################################################
#ressource group
Read_groupe(){
echo "Nom du groupe ressource"
read NomDuGroupe
}

Create_groupe(){
echo "Nom du groupe"
read NomDuGroupe
az group create --location eastus --name $NomDuGroupe
echo -e "${VERT}Groupe de ressource $NomDuGroupe crée !!${NC}"
}
################################################################
#vnet
Create_vnet(){

 az network vnet create -l eastus -g $NomDuGroupe -n $NomDuVnet --address-prefix $IpAddressVnet --subnet-name $NomDuSubnet --subnet-prefix $IpAddressSubnet
 
 echo -e "${VERT}Virtual Network crée !!${NC}"
}

##################################################################
# Load balancer :
#     -Ip publique
#     -ressource lb
#     -sonde integrité
#     -règle load balancer
Create_load_balancer(){
    #Ip publique
 az network public-ip create -g $NomDuGroupe --name $NomIpPublic --sku Standard
    #ressource LB
 az network lb create -g $NomDuGroupe --name $NomDuLb --sku Standard --public-ip-address $NomIpPublic --frontend-ip-name $FrontendIpName --backend-pool-name $NomBackendPool
    #sonde integrité
 az network lb probe create -g $NomDuGroupe --lb-name $NomDuLb -n $NomHealthProbe --protocol tcp --port 80
    #règle du LB
az network lb rule create --resource-group $NomDuGroupe --lb-name $NomDuLb --name $NomHTTPRule --protocol tcp --frontend-port 80 --backend-port 80 --frontend-ip-name $FrontendIpName --backend-pool-name $NomBackendPool --probe-name $NomHealthProbe --disable-outbound-snat true --idle-timeout 15 --enable-tcp-reset true

echo -e "${VERT}LoadBalancer crée  !!${NC}"
}
####################################################################
#creation groupe de securité reseau
#regle de groupe de securité reseau
Create_nsg(){
    #creation groupe
    az network nsg create --resource-group $NomDuGroupe --name $NomNSG
    #regle de securité1
    az network nsg rule create --resource-group $NomDuGroupe --nsg-name $NomNSG --name $NomNSGRuleHTTP --protocol '*' --direction inbound --source-address-prefix '*' --source-port-range '*' --destination-address-prefix '*' --destination-port-range 80 --access allow --priority 200
    #regle de securité2
    az network nsg rule create --resource-group $NomDuGroupe --nsg-name $NomNSG --name NSGRule22 --protocol '*' --direction inbound --source-address-prefix '*' --source-port-range '*' --destination-address-prefix '*' --destination-port-range 22 --access allow --priority 300

echo -e "${VERT}Network Security Groupe crée  !!${NC}"
}

##############################################################
# creation vm , interface reseau, ajout au pool backend LB    
    #creation interfaces reseau vm
Create_nic(){
az network nic create --resource-group $NomDuGroupe --name $compoNomNic --vnet-name $NomDuVnet --subnet $NomDuSubnet --network-security-group $NomNSG
}
    #creation des vms
Create_vm(){
az vm create -g $NomDuGroupe -n $compoNomVm --admin-username $compoAdminName --admin-password $compoAdminPwd --image Debian:debian-11:11-gen2:0.20210928.779 --size Standard_D2_v4 --authentication-type password --private-ip-address $compoPrivateIp --zone $numZone --no-wait --nics $compoNomNic       
#ouverture port
#commande qui semble inutile avec le nsg, ou a modifier
#  az vm open-port -g $NomDuGroupe -n $compoNomVm --port 80
#  az vm open-port -g $NomDuGroupe -n $compoNomVm --port 22
}
    #ajout de vm au pool backend du load balancer
Ajout_BE_Pool(){
az network nic ip-config address-pool add --address-pool $NomBackendPool --ip-config-name ipconfig1 --nic-name $compoNomNic --resource-group $NomDuGroupe --lb-name $NomDuLb    
}
#################################################################
Create_LB_InboundNat(){
### regle pour inbound nat port 22 pour la connexion en ssh sur chaque vm
az network lb inbound-nat-rule create --backend-port 22 --resource-group $NomDuGroupe --lb-name $NomDuLb --name PATvm22 --backend-pool-name $NomBackendPool --protocol Tcp --frontend-ip-name $FrontendIpName --frontend-port-range-start 33333 --frontend-port-range-end 33334
### regle pour inbound nat port 80 pour voir l'impact des changements via navigateur sur chaque vm separée sans avoir à en arreter une
az network lb inbound-nat-rule create --backend-port 80 --resource-group $NomDuGroupe --lb-name $NomDuLb --name PATvm80 --backend-pool-name $NomBackendPool --protocol Tcp --frontend-ip-name $FrontendIpName --frontend-port-range-start 44444 --frontend-port-range-end 44445
}

################################################################
#passerelle NAT
    #IP publique pour connectivité sortante
    #creation ressource Passerelle NAT
    #associer NAT au subnet
Create_NAT(){
#IP publique
az network public-ip create --resource-group $NomDuGroupe --name myNATgatewayIP --sku Standard --zone 1 2 3
#ressource Passerelle NAT
az network nat gateway create --resource-group $NomDuGroupe --name $NomNatGateway --public-ip-addresses myNATgatewayIP --idle-timeout 10
#associer NAT au subnet
az network vnet subnet update --resource-group $NomDuGroupe --vnet-name $NomDuVnet --name $NomDuSubnet --nat-gateway $NomNatGateway

echo -e "${VERT}NAT gateway crée  !!${NC}"
}

#################################################################
#azure database mariadb saas
Read_mariadb(){
echo "Nom du saas Mariadb"
read NomMariadb
}

Create_mariadb(){

az mariadb server create --name $NomMariadb --resource-group $NomDuGroupe --location eastus --admin-user $NomAdminMDB --admin-password $Passadmin --sku-name GP_Gen5_2 --version 10.3 --ssl-enforcement Disabled
###########ouverture port mariadb saas pour vm NAT
#recuperation ip NAT et autorisation de l'ip dans la database
IPNATsortant=$(az network public-ip show --resource-group $NomDuGroupe --name myNATgatewayIP | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
az mariadb server firewall-rule create --server-name $NomMariadb  --resource-group $NomDuGroupe --name accesDBrule --end-ip-address $IPNATsortant --start-ip-address $IPNATsortant

echo -e "${VERT}Database Azure mariaDB crée  !! ${NC}"

echo "nom hote database azure mariadb "$NomMariadb
echo "nom admin mariadb "$NomAdminMDB
echo "mot de passe admin mariadb Adminpass1"
}
#################################################################
#creation de vm avec nic et ajout be pool
Read_vm(){
    echo "Quel est le nombre de vm souhaité?"
    read NombreVm
}

CreateVMplus(){
    Create_nsg
    i=1
    while [ $i -le $NombreVm ]
    do
    compoNomVm=$NomVm$i
    compoAdminName=$AdminName$i
    compoAdminPwd=$AdminPwd$i
    compoPrivateIp=$PrivateIp$i
    compoNomNic=$NomNic$i
    #distribution des vms par zone
    numZone=$(($i%$nbzone+1))
    echo "Create vm"
    Create_nic
    Create_vm
    Ajout_BE_Pool
    i=$((i+1))
    done

    echo -e "${VERT}Les Virtual Machines ont été crées  !!${NC}"
}


RED='\033[0;31m'
VERT='\033[1;32m'
NC='\033[0m' # No Color
Read_vm
Read_mariadb
Create_groupe
Create_vnet
Create_load_balancer
CreateVMplus
Create_NAT
Create_LB_InboundNat
Create_mariadb