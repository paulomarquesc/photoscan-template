# Photoscan-template
Sample templates and scripts that deploys [Agisoft Photoscan](http://www.agisoft.com) product in Azure. This template was design to work with another sample template that deploys BeeGFS storage solution, so for a complete end-to-end scenario please deploy [this](https://github.com/paulomarquesc/beegfs-template) template first then you can continue. This is not a hard-requirement, you can use other storage solutions but the template will offer full automation if you rely on that BeeGFS template.

In summary, this template will deploy a virtual network with the following components:

![image](./media/photoscan.png)

This solution is break down into the following components, infrastructure items (Active Directory), Jumpboxes so you can connect to the environment, the Photoscan Scheduler (head) node and the processing nodes, finally, if you are using BeeGFS as your backend storage deployed using this [beegfs-template](https://github.com/paulomarquesc/beegfs-template), you can automatically peer the two virtual networks and install BeeGFS client on your processing nodes automatically with this template.

A sample deployment script called Deploy-AzureResourceGroup.sh is provided with this solution and you can use it to help automate your deployment. This is a minimal sample command line example which creates staging storage account to hold all deployment related files:

```bash
./Deploy-AzureResourceGroup.sh -g myResourceGroup -l eastus -t deploy-beegfs-master.json -p deploy-beegfs-master-parameters.json -r support-rg
```

## Prerequisites
1. To get end to end automation, please deploy [this](https://github.com/paulomarquesc/beegfs-template) template first.
1. Please make sure you review the parameter file before starting the deployment.

## Deployment Steps

### Sign in to Cloudshell
1. Open your browser and go to <a href="https://shell.azure.com" target="_new">https://shell.azure.com</a>

1. Sign on with `Microsoft Account` or `Work or School Account` associated with your Azure subscription

    ![image](./media/image1.png)


1. If you have access to more than one Azure Active Directory tenant, Select the Azure directory that is associated with your Azure subscription
    
    ![image](./media/image2.png)

1. If this is the first time you accessed the Cloud Shell, `Select` "Bash (Linux)" when asked which shell to use.

    ![image](./media/image3.png)

    > Note: If this is not the first time and it is the "Powershell" shell that starts, please click in the dropdown box that shows "PowerShell" and select "Bash" instead.

1. If you have at least contributor rights at subscription level, please select which subscription you would like the initialization process to create a storage account and click "Create storage" button.
    ![image](./media/image4.png)

2. You should see a command prompt like this one:
    ![image](./media/image5.png)


### Cloning the source sample project
1. Change folder to your clouddrive so any changes gets persisted in the storage account assigned to your cloudshell
   ```bash
   cd ~/clouddrive
   ```
1. Clone this repository with the following git command
   ```bash
   git clone https://github.com/paulomarquesc/beegfs-template.git
   ```
1. Change folder to beegfs-template
   ```bash
   cd beegfs-template
   ```
1. Review and change all of these parameters files before deploying
   *  deploy-beegfs-master-parameters.json
   *  deploy-beegfs-nodes-parameters.json
   *  deploy-clients-parameters.json

2. Execute the deployment scripts for each of the templates (make sure you change command line arguments), it must be in this specific order
    * deploy-beegfs-master.json
        ```bash
        ./Deploy-AzureResourceGroup.sh -g beegfs-rg -l eastus -t deploy-beegfs-master.json -p deploy-beegfs-master-parameters.json -s storageaccountname -r storage-account-rg
        ```
    * deploy-beegfs-nodes.json
        ```bash
        ./Deploy-AzureResourceGroup.sh -g beegfs-rg -l eastus -t deploy-beegfs-nodes.json -p deploy-beegfs-nodes-parameters.json -s storageaccountname -r storage-account-rg
        ```
    * deploy-clients.json (this is optional, this is an example on how to have clients connected to BeeGFS and this is specifically useful to my other project were I had some Windows clients having to get access to the same data on BeeGFS as the Linux clients)
        ```bash
        ./Deploy-AzureResourceGroup.sh -g beegfs-rg -l eastus -t deploy-clients.json -p deploy-clients-parameters.json -s storageaccountname -r storage-account-rg
        ```

    > Note: inside devtools folder there is a simple script that ties all deployments together, you can copy it to the beegfs-template folder, change its values and execute one script for the whole environment.

### List of parameters per template and their descriptions
#### deploy-beegfs-master-parameters.json
* **_artifactsLocation:** Auto-generated container in staging storage account to receive post-build staging folder upload.
* **_artifactsLocationSasToken:** Auto-generated token to access _artifactsLocation.
* **location:** Location where the resources of this template will be deployed to. Default Value: `eastus`
* **dnsDomainName:** DNS domain name use to build the host's FQDN. If using this parameter, make sure that there is a DNS server serving the vnet before the BeeGFS servers gets deployed.
* **beeGfsMasterVmName:** Management (master) BeeGfs VM name. Default Value: `beegfsmaster`
* **VMSize:** sku to use for the storage nodes - only premium disks VMs are allowed. Default Value: `Standard_DS3_v2`
* **VMImage:** VM Image. Default Value: `CentOS_7.5`
* **vnetRG:** Resoure group name where the virtual network is located. Defaults to deployment Resource Group. Default Value: `none`
* **vnetName:** Vnet name. Default Value: `beegfs-vnet`
* **subnetName:** Subnet name where BeeGFS components will be deployed to. Default Value: `beegfs-subnet`
* **addressPrefix:** Vnet IP Address Space. Default Value: `192.168.0.0/16`
* **subnetPrefix:** Subnet ip address range. Default Value: `192.168.0.0/24`
* **beeGfsMasterIpAddress:** BeeGFS Management(master) node Static Ip Address. Default Value: `192.168.0.4`
* **adminUsername:** Admin username on all VMs.
* **sshKeyData:** SSH rsa public key file as a string.
* **beegfsShareName:** This indicates beegfs mount point on master and storage+meta nodes. Default Value: `192.168.0.4`
* **beegfsHpcUserHomeFolder:** This indicates beegfs mount point on master and storage+meta nodes for the hpcuser home folder, mounted on all nodes. Default Value: `/mnt/beegfshome`
* **hpcUser:** Hpc user that will be owner of all files in the hpc folder structure. Default Value: `hpcuser`
* **hpcUid:** Hpc User ID. Default Value: `7007`
* **hpcGroup:** Hpc Group. Default Value: `hpcgroup`
* **hpcGid:** Hpc Group ID. Default Value: `7007`

#### deploy-beegfs-nodes-parameters.json
* **_artifactsLocation:** Auto-generated container in staging storage account to receive post-build staging folder upload.
* **_artifactsLocationSasToken:** Auto-generated token to access _artifactsLocation.
* **location:** Location where the resources of this template will be deployed to. Default Value: `westus2`
* **vmssName:** OSS/MDS (Storage/Meta) VMSS name. Default Value: `beegfsserver`
* **dnsDomainName:** DNS domain name use to build the host's FQDN.
* **nodeType:** type of beegfs node to deploy. Default Value: `all`
* **nodeCount:** Number of BeeGFS nodes (100 or less). Default Value: `1`
* **VMSize:** sku to use for the storage nodes - only premium disks VMs are allowed. Default Value: `Standard_DS3_v2`
* **VMImage:** VM Image. Default Value: `CentOS_7.5`
* **vnetName:** Vnet name. Default Value: `beegfs-vnet`
* **subnetName:** Subnet name. Default Value: `beegfs-subnet`
* **adminUsername:** Admin username on all VMs.
* **sshKeyData:** SSH rsa public key file as a string.
* **storageDiskSize:** Premium storage disk size used for the storage services. Default Value: `P10`
* **StorageDisksCount:** Number of storage disks. Default Value: `1`
* **metaDiskSize:** Premium storage disk size used for the metadata services. Default Value: `P10`
* **MetaDisksCount:** Number of metadata disks. Default Value: `1`
* **volumeType:** Volume for data disks. Default Value: `RAID0`
* **vnetRg:** Name of the RG of the virtual network which master server is using.
* **masterName:** Name of master VM name. Default Value: `beegfsmaster`
* **beeGfsMountPoint:** Shared BeeGFS data mount point, Smb Share (beeGfsSmbShareName) will be a subfolder under this mount point. Default Value: `/beegfs`
* **beegfsHpcUserHomeFolder:** This indicates beegfs mount point on master and storage+meta nodes for the hpcuser home folder, mounted on all nodes. Default Value: `/mnt/beegfshome`
* **hpcUser:** Hpc user that will be owner of all files in the hpc folder structure. Default Value: `hpcuser`
* **hpcUid:** Hpc User ID. Default Value: `7007`
* **hpcGroup:** Hpc Group. Default Value: `hpcgroup`
* **hpcGid:** Hpc Group ID. Default Value: `7007`
* **deployHaConfiguration:** BeeGFS HA Configuration Deployment. Default Value: `yes`

#### deploy-clients-parameters.json
* **_artifactsLocation:** Auto-generated container in staging storage account to receive post-build staging folder upload.
* **_artifactsLocationSasToken:** Auto-generated token to access _artifactsLocation.
* **location:** Location where the resources of this template will be deployed to. Default Value: `eastus`
* **vnetRG:** Resoure group name where the virtual network is located.
* **vnetName:** Name of the the Virtual Network where the subnet will be added. Default Value: `beegfs-vnet`
* **subnetName:** Existing subnet name. Default Value: `beegfs-subnet`
* **subnetIpAddressSuffix:** Clients will have static Ip addresses, this is the network part of a class C subnet. Default Value: `192.168.0`
* **startIpAddress:** Clients will have static Ip addresses, this is the start number of the host part of the class C ip address. Default Value: `50`
* **nodeCount:** Number of client nodes (100 or less). Default Value: `1`
* **vmNameSuffix:** VM name suffix. Default Value: `beegfsclt`
* **VMSize:** sku to use for the storage nodes - only premium disks VMs are allowed. Default Value: `Standard_DS3_v2`
* **VMImage:** VM Image. Default Value: `CentOS_7.5`
* **dnsDomainName:** DNS domain name use to build the host's FQDN.
* **adminUsername:** Name of admin account of the VMs, this name cannot be well know names, like root, admin, administrator, guest, etc.
* **sshKeyData:** SSH rsa public key file as a string.
* **nodeType:** type of beegfs node to deploy. Default Value: `client`
* **masterName:** Name of master VM name. Default Value: `beegfsmaster`
* **sambaWorkgroupName:** Name of samba workgroup. Default Value: `WORKGROUP`
* **beeGfsMountPoint:** Shared BeeGFS data mount point, Smb Share (beeGfsSmbShareName) will be a subfolder under this mount point. Default Value: `/beegfs`
* **beeGfsSmbShareName:** Samba share name. It will be a subfolder as well under beeGfsMountPoint. Default Value: `beegfsshare`
* **beegfsHpcUserHomeFolder:** This indicates beegfs mount point on master and storage+meta nodes for the hpcuser home folder, mounted on all nodes. Default Value: `/mnt/beegfshome`
* **hpcUser:** Hpc user that will be owner of all files in the hpc folder structure. Default Value: `hpcuser`
* **hpcUid:** Hpc User ID. Default Value: `7007`
* **hpcGroup:** Hpc Group. Default Value: `hpcgroup`
* **hpcGid:** Hpc Group ID. Default Value: `7007`
* **smbVip:** SMB Clients Virtual Ip Address. Default Value: `192.168.0.55`

## References
BeeGFS - https://www.beegfs.io

AzureCAT Parallel File System eBook - https://blogs.msdn.microsoft.com/azurecat/2018/06/11/azurecat-ebook-parallel-virtual-file-systems-on-microsoft-azure/

Original BeeGFS template from AzureCAT team - https://github.com/az-cat/HPC-Filesystems
