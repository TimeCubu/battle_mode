# check what aws account you are using
aws sts get-caller-identity

# aws command to create a user and an secret/access key pair
aws iam create-user --user-name terraform
aws iam create-access-key --user-name terraform

# add policy to the user to be able to deploy the infrastructure
aws iam attach-user-policy --user-name terraform --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# aws command to check the security group attached to the ec2 instance
aws ec2 describe-instances --instance-ids i-0b1b3b3b3b3b3b3b3 --query 'Reservations[*].Instances[*].SecurityGroups[*].GroupId'
# aws command to get all details of the ec2 instance
aws ec2 describe-instances --instance-ids i-0b1b3b3b3b3b3b3b3
# aws command to check the security group details
aws ec2 describe-security-groups --group-ids sg-0b1b3b3b3b3b3b3b3

# aws command to allow all traffic to the security group
aws ec2 authorize-security-group-ingress --group-id sg-0b1b3b3b3b3b3b3b3 --protocol all --cidr

# aws command to allow http/https traffic to the security group
aws ec2 authorize-security-group-ingress --group-id sg-0b1b3b3b3b3b3b3b3 --protocol tcp --port 80 --cidr

# aws command to check if subnet is public or private
aws ec2 describe-subnets --subnet-ids subnet-0b1b3b3b3b3b3b3b3 --query 'Subnets[*].MapPublicIpOnLaunch'

# aws command to check the route table attached to the subnet
aws ec2 describe-route-tables --route-table-ids rtb-0b1b3b3b3b3b3b3b3 --query 'RouteTables[*].Associations[*].RouteTableId'

# aws command to check the route table details
aws ec2 describe-route-tables --route-table-ids rtb-0b1b3b3b3b3b3b3b3

# get the top file ips from a logs file
cat /var/log/nginx/access.log | awk '{print $1}' | sort | uniq -c | sort -nr | head -n 10

# aws command to check the internet gateway attached to the vpc
aws ec2 describe-internet-gateways --filter Name=attachment.vpc-id,Values=vpc-0b1b3b3b3b3b3b3b3 --query 'InternetGateways[*].InternetGatewayId'