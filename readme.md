run the install script, to as the prerequisite ,
 aws configure: input your access_key    and secret_key  
 aws configure list to confirm connection
Install using Fargate
eksctl create cluster --name demo-cluster --region us-east-1 --fargate
// reason why i used fargate ...
Delete the cluster
eksctl delete cluster --name demo-cluster --region us-east-1
dont forget to delete cluster one demo is done 
