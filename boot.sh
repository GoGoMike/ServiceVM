#!/bin/bash
### Spinner for heavy tasks ###
Fn_Spinner() {
  SpinChars='/-\|'
  tput sc
  while true; do
    printf -- '\b%.1s' "${SpinChars}"
    SpinChars=${SpinChars#?}${SpinChars%???}
    tput rc
    sleep 1
  done
}

Fn_EndSpinner() {
  kill "${SpinPID}"
  wait "${SpinPID}" 2>/dev/null
}

echo "##########Starting dnf update##########"
echo " Please wait, this might take a while "
Fn_Spinner &
SpinPID=$!
sudo dnf update -y -q  2>&1 >/dev/null
Fn_EndSpinner

echo ""
echo "###########Update completed############"
sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
sudo setenforce 0
echo "###########SElinux disabled############"
sudo mkdir -p /kvm/{images,iso}
mkdir $HOME/migration
echo "##########Directories created##########"
echo ""

echo "#####Installing libvirt & utilities####"
Fn_Spinner &
SpinPID=$!
sudo dnf module install virt -y -q &&
Fn_EndSpinner

echo "#####Installing libvirt & utilities####"
Fn_Spinner &
SpinPID=$!
sudo dnf install virt-install virt-viewer libguestfs-tools -y -q
Fn_EndSpinner

echo "###Starting and configuring libvirtd###"
sudo systemctl enable libvirtd.service --now
virsh pool-define-as default dir - - - - "/kvm/images"
virsh pool-build default && virsh pool-autostart default && virsh pool-start default
echo "####Installing virt-v2v & OS-client####"
sudo dnf install virt-v2v virtio-win -y -q
sudo dnf install centos-release-openstack-train -y -q 
sudo sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-OpenStack-train.repo && sudo sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-OpenStack-train.repo
sudo sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/ceph-nautilus.repo && sudo sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/ceph-nautilus.repo
sudo dnf install python3-openstackclient ansible -y -q
echo "##########Configuring ansible##########"
ansible-galaxy collection install community.vmware
sudo sed -i '/#enable_plugins/ a enable_plugins = host_list, script, auto, yaml, ini, community.vmware.vmware_vm_inventory, vmware_vm_inventory' /etc/ansible/ansible.cfg
pip3 install --user --upgrade pip setuptools
pip3 install --user --upgrade git+https://github.com/vmware/vsphere-automation-sdk-python.git
sleep 2
echo "export LIBGUESTFS_BACKEND=direct" >> $HOME/.bashrc
### Y/n reboot question ###
read -r -p "All done, go to reboot? [Y/n]" response
response=${response,,}
if [[ $response =~ ^(yes|y| ) ]] || [[ -z $response ]]; then
sudo shutdown -r now
else
echo "Bye! Bye!"
fi
