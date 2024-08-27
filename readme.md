

# EKS Setup with eksctl and Fargate

## Prerequisites

Before you begin, ensure that you have the following installed and configured on your machine:

- **AWS CLI**: Used to interact with AWS services.
- **kubectl**: Kubernetes command-line tool to manage Kubernetes clusters.
- **eksctl**: A command-line tool for creating and managing Kubernetes clusters on EKS.

If these tools are not installed, use the provided `install.sh` script to set them up.

## Installation Script

The `install.sh` script automates the installation of the necessary tools. To run it:

```bash
chmod +x install.sh
./install.sh
```

### Why are we installing these tools?

- **kubectl**: This is the Kubernetes command-line tool that allows you to run commands against Kubernetes clusters. You need it to deploy and manage applications on your EKS cluster.
- **eksctl**: This tool simplifies the creation and management of EKS clusters, which is crucial for setting up your Kubernetes environment on AWS.
- **AWS CLI**: Required for interacting with AWS services from your command line. It's essential for configuring your AWS credentials, setting up IAM roles, and managing other AWS resources.

### Configure AWS CLI

After running the script, configure your AWS CLI with your credentials:

```bash
aws configure
```

You will be prompted to enter your `AWS Access Key ID`, `AWS Secret Access Key`, `Default region name`, and `Default output format`. Ensure that you have configured these correctly.

**Why configure AWS CLI?**  
This step is essential because `eksctl`, `kubectl`, and other AWS tools will rely on these credentials to authenticate and interact with AWS services. Without proper configuration, these tools won't be able to access your AWS account.

To confirm that the AWS CLI is connected, run:

```bash
aws configure list
```

## Creating an EKS Cluster with Fargate

1. **Create a Fargate EKS Cluster**:

   Use the following command to create an EKS cluster named `demo-cluster` in the `us-east-1` region:

   ```bash
   eksctl create cluster --name demo-cluster --region us-east-1 --fargate
   ```

   **Why create an EKS cluster with Fargate?**  
   - **EKS** (Elastic Kubernetes Service) is a managed service that makes it easy to run Kubernetes on AWS without needing to install and operate your own Kubernetes control plane or nodes.
   - **Fargate** is a serverless compute engine that lets you run containers without having to manage the underlying infrastructure. It automatically provisions and scales compute resources, so you can focus on building and running your applications instead of managing servers.

2. **Update kubeconfig**:

   After creating the cluster, update your kubeconfig file to interact with the cluster:

   ```bash
   aws eks update-kubeconfig --name demo-cluster --region us-east-1
   ```

   **Why update kubeconfig?**  
   This step updates your local Kubernetes configuration file (`kubeconfig`) to include the credentials and endpoint information of your newly created EKS cluster. This is necessary to allow `kubectl` to communicate with your EKS cluster.

## Deploying a Sample Application (2048 Game)

### Create a Fargate Profile

To run a specific application on Fargate, create a Fargate profile:

```bash
eksctl create fargateprofile \
    --cluster demo-cluster \
    --region us-east-1 \
    --name alb-sample-app \
    --namespace game-2048
```

**Why create a Fargate profile?**  
A Fargate profile allows you to specify which pods (Kubernetes workloads) should run on Fargate. This profile essentially tells the EKS cluster which namespaces and labels to consider for Fargate, ensuring that your specific application (in this case, the 2048 game) runs in a serverless manner.

### Deploy the Application

Deploy the sample 2048 game application using Kubernetes manifest files:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/examples/2048/2048_full.yaml
```

**Why deploy this application?**  
Deploying the 2048 game serves as a practical example of how to run an application on your EKS cluster. This step demonstrates how to use `kubectl` to deploy applications and how they are managed within the Kubernetes ecosystem.

## Setting up IAM OIDC Provider

### Configure IAM OIDC Provider

First, export the cluster name:

```bash
export cluster_name=demo-cluster
```

Then, get the OIDC ID:

```bash
oidc_id=$(aws eks describe-cluster --name $cluster_name --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
```

Check if there is an existing IAM OIDC provider configured:

```bash
aws iam list-open-id-connect-providers | grep $oidc_id | cut -d "/" -f4
```

If there is no existing provider, associate one with your cluster:

```bash
eksctl utils associate-iam-oidc-provider --cluster $cluster_name --approve
```

**Why configure the IAM OIDC Provider?**  
The IAM OIDC provider is necessary for creating IAM roles that Kubernetes service accounts can assume. This is especially important when deploying applications that require access to other AWS services. The OIDC provider allows EKS to securely manage credentials for these service accounts.

## Setting Up ALB Add-on

### Download IAM Policy

Download the IAM policy required for the ALB (Application Load Balancer) controller:

```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json
```

**Why download this policy?**  
The ALB controller requires specific permissions to manage load balancers within your AWS account. This policy defines those permissions, ensuring that the ALB controller can create, manage, and delete load balancers as needed by your Kubernetes applications.

### Create IAM Policy

Create the IAM policy in AWS:

```bash
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json
```

**Why create an IAM policy?**  
By creating this IAM policy, you grant the necessary permissions to the ALB controller, enabling it to function correctly within your EKS cluster. This is a critical step to ensure that your applications can use AWS load balancers for traffic management.

### Create IAM Role

Create an IAM service account with the necessary role:

```bash
eksctl create iamserviceaccount \
  --cluster=<your-cluster-name> \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::<your-aws-account-id>:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve
```

**Why create an IAM role?**  
This IAM role is attached to the Kubernetes service account used by the ALB controller. It ensures that the ALB controller has the appropriate permissions to manage AWS resources like load balancers on behalf of your EKS cluster.

### Deploy ALB Controller

Add the Helm chart repository:

```bash
helm repo add eks https://aws.github.io/eks-charts
```

Update the repo:

```bash
helm repo update eks
```

Install the ALB controller:

```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \            
  -n kube-system \
  --set clusterName=<your-cluster-name> \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=<region> \
  --set vpcId=<your-vpc-id>
```

**Why install the ALB controller?**  
The ALB controller allows Kubernetes to manage AWS Application Load Balancers (ALBs). This integration is crucial for exposing Kubernetes services to external traffic and managing ingress in your EKS cluster.

Verify the deployment:

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

## Deleting the Cluster

Once you are done with the demo or no longer need the cluster, delete it to avoid incurring costs:

```bash
eksctl delete cluster --name demo-cluster --region us-east-1
```

**Why delete the cluster?**  
AWS charges for running EKS clusters, so it’s important to delete the cluster when it's no longer needed to avoid unnecessary costs.

## Summary

This guide walks you through the process of setting up an Amazon EKS cluster using `eksctl`, deploying a sample application with Fargate, configuring necessary IAM roles, and managing the ALB controller. Each step includes a brief explanation of why it's important, helping you understand the purpose behind the actions you're taking. Make sure to clean up the cluster after your demo to prevent incurring additional charges.
