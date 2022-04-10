#!/bin/bash
MEMORY_AVAIL=`free -m | grep Mem | awk '{print $7}'`
echo "Tööriista paigaldus"
START_TIME=$SECONDS
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
echo "Tööriista paigaldus võttis $(($SECONDS - $START_TIME)) sekundit"
echo "Tööriistaga klastri loomine."
START_TIME=$SECONDS
free -m
k3d cluster create mycluster --config run_k3d.yaml
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
k3d cluster delete mycluster
echo "Kustutamine võttis $(($SECONDS - $START_TIME)) sekundit."

