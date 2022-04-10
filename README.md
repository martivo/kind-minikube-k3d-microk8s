

The terraform code will create virtual machines with Ubuntu and installs docker on them. It also copies the relevant run_\* scripts to each create VM.
Each script installs specific tool, then installs a kubernetes cluster using contianers and finally removes the cluster.
These scripts are used to compare the memory requirements and speed of each tool.

## Usage
To create virtualmachines for the measurement set AWS credentials with env variables: AWS_ACCESS_KEY_ID and AWS_SERET_ACCESS_KEY.
Pass the three following variables to terraform:
* tutor-ssh-key - name of your ssh key in AWS EC2. To create or import it login to AWS Web Console and navigate to EC2 > Key Pairs.
* aws-region  - the AWS region to use, for example "eu-central-1"
* node-instance-type - the AWS EC2 instance type, for example "m5.large"

```
terraform init
terraform apply -var="tutor-ssh-key=mykey" -var="aws-region=eu-central-1" -var="node-instance-type=m5.large"
```

The terraform apply command will output the IP adresses of the created linux machines for each tool: kind, minikube, k3d and microk8s.
The scripts will install, create and delete the kubernetes clusters. Measures the time and memory it takes to complate.

```
ssh ubuntu@...
./run_*.sh
```

