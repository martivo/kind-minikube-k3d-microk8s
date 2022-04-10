#!/bin/bash
MEMORY_AVAIL=`free -m | grep Mem | awk '{print $7}'`
echo "Tööriista paigaldus"
START_TIME=$SECONDS
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/bin/kind
echo "Tööriista paigaldus võttis $(($SECONDS - $START_TIME)) sekundit"
echo "Tööriistaga klastri loomine."
START_TIME=$SECONDS
free -m
kind create cluster --config run_kind.yaml
echo "Tööriista käivitamine võttis $(($SECONDS - $START_TIME)) sekundit"
echo "Kontroll kas kõik töötaja masinad on valmis."
START_TIME=$SECONDS
foo=$(kubectl  describe nodes | grep KubeletReady | wc -l)
while [ "$foo" -lt "8" ]
do
        sleep 1
        foo=$(kubectl  describe nodes | grep KubeletReady | wc -l)
        echo "$foo nodes ready, waiting."
done
kubectl get nodes
kubectl get pods -n kube-system
echo "Kõik töötaja masinad on valmis $(($SECONDS - $START_TIME)) sekundiga."
MEM_NOW=`free -m | grep Mem | awk '{print $7}'`
echo "Mälukasutuse muutus on $(($MEMORY_AVAIL - $MEM_NOW))"
free -m
START_TIME=$SECONDS
kind delete cluster --name multi-a
echo "Kustutamine võttis $(($SECONDS - $START_TIME)) sekundit."

