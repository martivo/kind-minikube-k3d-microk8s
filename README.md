
= Usage =
The terraform code will create virtual machines with Ubuntu and installs docker on them. It also copies the relevant run_\* scripts to each create VM.


To create virtualmachines for the measurement set AWS credentials with env variables: AWS_ACCESS_KEY_ID and AWS_SERET_ACCESS_KEY.

```
terraform init
terraform apply
```

The terraform apply command will output the IP adresses of the created linux machines for each tool: kind, minikube, k3d and microk8s.
The scripts will install, create and delete the kubernetes clusters. Measures the time and memory it takes to complate.

```
ssh ubuntu@...
./run_*.sh
```

