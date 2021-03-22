#!/bin/bash


### Usage :
# chmod 700 k8s-provisioning.sh
# ./k8s-provisioning.sh [master-node-hostname] [worker-node-hostname]
# ex : ./k8s-provisioning.sh master.example.com worker.example.com
##########################################################

## $1 == master node
## $2 == worker node
arr=( $1 $2 )
version='1.19.8-00'

echo "Master node = ${arr[0]}"
echo "Worker node = ${arr[1]}"
for i in "${arr[@]}"
  do 
    echo "############################"
    echo "##### Updating package #####"
    echo "############################"
    echo " "
    ssh $i "sudo apt update && sudo apt upgrade -y"
    sleep 1
    echo "############################"
    echo "##### Enable bridge-nf #####"
    echo "############################"
    echo " "
    cat << EOF | ssh $i 'sudo tee -a /etc/sysctl.d/k8s.conf'
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
    ssh $i "sudo sysctl --system"
    echo "##############################"
    echo "###### Install Docker ########"
    echo "##############################"
    echo " "
    ssh $i "sudo apt install apt-transport-https ca-certificates curl software-properties-common -y"
    ssh $i "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -"
    ssh $i 'sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"'
    ssh $i 'sudo apt install docker-ce -y'
done

echo "######################################################"
echo "######## Install kubeadm kubectl and kubelet #########"
echo "######################################################"
echo " "
for i in "${arr[@]}"
  do 
    ssh $i "curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -"
    cat << EOF | ssh $i 'sudo tee -a /etc/apt/sources.list.d/kubernetes.list'
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
    ssh $i 'sudo apt update'
    ssh $i "sudo apt-get install -y kubelet=$version kubeadm=$version kubectl=$version"
    ssh $i 'sudo apt-mark hold kubelet kubeadm kubectl'
done
echo " "
echo "#########################################"
echo "######### Bootraping Master #############"
echo "#########################################"
echo " "
ssh ${arr[0]} "sudo kubeadm init --pod-network-cidr 192.168.0.0/16"

echo " "
echo "#########################################"
echo "######## Get Kubernetes Config #########"
echo "#########################################"
echo " "
ssh ${arr[0]} 'mkdir -p $HOME/.kube'
ssh ${arr[0]} 'sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config'
ssh ${arr[0]} 'sudo chown $(id -u):$(id -g) $HOME/.kube/config'

echo " "
echo "######################################"
echo "######### Add Worker Node ############"
echo "######################################"
echo " "
ssh ${arr[0]} "sudo kubeadm token create --print-join-command | grep kubeadm | xargs ssh ${arr[1]}"

echo " "
echo "#############################"
echo "######## Install CNI ########"
echo "#############################"
echo " "
ssh ${arr[0]} "curl https://docs.projectcalico.org/manifests/calico.yaml -O"
ssh ${arr[0]} "kubectl apply -f calico.yaml"
sleep 10