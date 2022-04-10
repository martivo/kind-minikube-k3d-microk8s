#!/bin/bash
MEMORY_AVAIL=`free -m | grep Mem | awk '{print $7}'`
echo "Tööriista paigaldus"
START_TIME=$SECONDS
#sudo snap install lxd
sudo apt update
sudo apt -y install lxd
sudo lxd init --auto --storage-backend=dir 
lxc profile create microk8s
wget https://raw.githubusercontent.com/ubuntu/microk8s/master/tests/lxc/microk8s.profile -O microk8s.profile
cat microk8s.profile | lxc profile edit microk8s
rm microk8s.profile
lxc network list
echo "Tööriista paigaldus võttis $(($SECONDS - $START_TIME)) sekundit"
echo "Tööriistaga klastri loomine."
START_TIME=$SECONDS
free -m
#https://microk8s.io/docs/lxd
#https://ubuntu.com/tutorials/getting-started-with-kubernetes-ha?&_ga=2.199186223.1894255953.1646810874-1723796373.1646050010#4-create-a-microk8s-multinode-cluster

lxc launch -p default -p microk8s ubuntu:20.04 microk8s-m1
lxc launch -p default -p microk8s ubuntu:20.04 microk8s-m2 &
lxc launch -p default -p microk8s ubuntu:20.04 microk8s-m3 &
lxc launch -p default -p microk8s ubuntu:20.04 microk8s-w1 &
lxc launch -p default -p microk8s ubuntu:20.04 microk8s-w2 &
lxc launch -p default -p microk8s ubuntu:20.04 microk8s-w3 &
lxc launch -p default -p microk8s ubuntu:20.04 microk8s-w4 &
lxc launch -p default -p microk8s ubuntu:20.04 microk8s-w5 &
while [ "$(lxc list | grep RUNNING | wc -l)" -ne 8 ]
do
        sleep 0.1
done
lxc exec microk8s-m1 -- snap install microk8s --classic
lxc exec microk8s-m2 -- snap install microk8s --classic
lxc exec microk8s-m3 -- snap install microk8s --classic
lxc exec microk8s-w1 -- snap install microk8s --classic
lxc exec microk8s-w2 -- snap install microk8s --classic
lxc exec microk8s-w3 -- snap install microk8s --classic
lxc exec microk8s-w4 -- snap install microk8s --classic
lxc exec microk8s-w5 -- snap install microk8s --classic
lxc exec microk8s-m1 -- microk8s status --wait-ready
lxc exec microk8s-m2 -- microk8s status --wait-ready
lxc exec microk8s-m3 -- microk8s status --wait-ready
join_cmd=$(lxc exec microk8s-m1 -- microk8s add-node --format short | head -1)
lxc exec microk8s-m2 -- $join_cmd --controlplane
join_cmd=$(lxc exec microk8s-m1 -- microk8s add-node --format short | head -1)
lxc exec microk8s-m3 -- $join_cmd --controlplane
join_cmd=$(lxc exec microk8s-m1 -- microk8s add-node --format short | head -1)
lxc exec microk8s-w1 -- $join_cmd --worker
join_cmd=$(lxc exec microk8s-m1 -- microk8s add-node --format short | head -1)
lxc exec microk8s-w2 -- $join_cmd --worker
join_cmd=$(lxc exec microk8s-m1 -- microk8s add-node --format short | head -1)
lxc exec microk8s-w3 -- $join_cmd --worker
join_cmd=$(lxc exec microk8s-m1 -- microk8s add-node --format short | head -1)
lxc exec microk8s-w4 -- $join_cmd --worker
join_cmd=$(lxc exec microk8s-m1 -- microk8s add-node --format short | head -1)
lxc exec microk8s-w5 -- $join_cmd --worker
echo "Tööriista käivitamine võttis $(($SECONDS - $START_TIME)) sekundit"
echo "Kontroll kas kõik töötaja masinad on valmis."
START_TIME=$SECONDS
foo=$(lxc exec microk8s-m1 -- microk8s kubectl describe nodes | grep KubeletReady | wc -l)
while [ "$foo" -lt "8" ]
do
        sleep 1
        foo=$(lxc exec microk8s-m1 -- microk8s kubectl describe nodes | grep KubeletReady | wc -l)
        echo "$foo nodes ready, waiting."
done
lxc exec microk8s-m1 -- microk8s kubectl get nodes
lxc exec microk8s-m1 -- microk8s kubectl get pods -n kube-system
echo "Kõik töötaja masinad on valmis $(($SECONDS - $START_TIME)) sekundiga."
MEM_NOW=`free -m | grep Mem | awk '{print $7}'`
echo "Mälukasutuse muutus on $(($MEMORY_AVAIL - $MEM_NOW))"
free -m
START_TIME=$SECONDS
lxc delete microk8s-m1 microk8s-m2 microk8s-m3 microk8s-w1 microk8s-w2 microk8s-w3 microk8s-w4 microk8s-w5 --force
echo "Kustutamine võttis $(($SECONDS - $START_TIME)) sekundit."

