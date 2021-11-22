## Rook Ceph - Cloud Native Storage
***

### Prerequisites

- Docker
- Helm
- Minikube
- Kubectl
- Conntrack
- LVM package

***
**In order to configure the Ceph storage cluster, at least one of these local storage options are required:**

 - Raw devices (no partitions or formatted filesystems)
 - This requires lvm2 to be installed on the host. To avoid this dependency, you can create a single full-disk partition on the disk (see below)
Raw partitions (no formatted filesystem)
 - Persistent Volumes available from a storage class in block mode
***

_we can leave some free space on the hard drive, and create a cleared partition, which ceph can use this one._


I've left 9 GiB free space on my hard drive:

```bash
lsblk 
```
>```
>NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
>sda      8:0    0 238,5G  0 disk
>├─sda4   8:4    0  71,5G  0 part /
>├─sda5   8:5    0 149,2G  0 part /home
>└─sda6   8:6    0   9,3G  0 part
> ```

**Before Rook Cluster creation**

```bash
lsblk -f
```
>```
>NAME   FSTYPE   LABEL     UUID                                 FSAVAIL FSUSE%  MOUNTPOINT
>sda
>├─sda4 ext4               4c389323-a6fc-4ca5-b140-c0322ce41379     43G    33%   /
>├─sda5 ext4               bc907f15-89e7-43b6-ab55-1b9d91a5ecec  128,3G     7%   /home
>└─sda6 
>```

_If the FSTYPE field is not empty, there is a filesystem on top of the corresponding device. In this example, you can use sda6 for Ceph and can’t use sda4 and sda5 its partitions._

### Conntrack

- Ubuntu

```bash
sudo apt-get install -y conntrack
```

### LVM package

- Ubuntu

```bash
sudo apt-get install -y lvm2
```

### Helm repos

```bash
helm repo add rook-release https://charts.rook.io/release
helm repo update
```

### Create Cluster Linux none (bare-metal) driver

```bash
sudo -E minikube start --driver=none
```

### Install Rook Ceph

```bash
helm install --create-namespace --namespace rook-ceph rook-ceph rook-release/rook-ceph
```

### Deploy a Test Cluster

```bash
kubectl apply -f storage/cluster-test.yaml
```

**After Rook Cluster created**

_we can note the ceph_bluesto as FSTYPE for sda6_

```
lsblk -f
```
>```
>sda
>├─sda4 ext4               4c389323-a6fc-4ca5-b140-c0322ce41379     43G    33% /
>├─sda5 ext4               bc907f15-89e7-43b6-ab55-1b9d91a5ecec  128,3G     7% /home
>└─sda6 ceph_bluesto                                                           
>rbd0
>```

### Deploy a test Storage Class

```bash
kubectl apply -f storage/storageclass-test.yaml
```

### Test the new StorageClass using Mysql

```bash
kubectl apply -f storage/mysql.yaml
```