#!/bin/bash

# Script to install essential utilities and tools on Ubuntu
# Exit on any error
set -e

# Update and upgrade packages
sudo apt update -y && sudo apt upgrade -y

# Install Python3 and Pip3
sudo apt install -y python3 python3-pip

# Install essential utilities
sudo apt install -y curl git unzip wget zsh tmux

# Install AWS CLI
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi

# Install Node.js & npm
sudo apt install -y nodejs npm

# Install ripgrep (rg)
sudo apt install -y ripgrep

# Install bat (alternative to cat)
sudo apt install -y bat

# Install fzf (fuzzy finder)
sudo apt install -y fzf

# Install eksctl (EKS CLI)
if ! command -v eksctl &> /dev/null; then
      # for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
      ARCH=amd64
      PLATFORM=$(uname -s)_$ARCH

      curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"

      # (Optional) Verify checksum
      curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check

      tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz

      sudo mv /tmp/eksctl /usr/local/bin
fi

# Install Helm (Kubernetes package manager)
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Install kubectx and kubens (Easier context switching)
sudo apt install -y kubectx

# Install AWS IAM Authenticator (for EKS authentication)
if ! command -v aws-iam-authenticator &> /dev/null; then
    echo "Installing AWS IAM Authenticator..."
    curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.19.6/2021-07-05/bin/linux/amd64/aws-iam-authenticator
    chmod +x aws-iam-authenticator
    sudo mv aws-iam-authenticator /usr/local/bin/
fi

# Install Miniconda
if ! command -v conda &> /dev/null; then
    echo "Installing Miniconda..."
    curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    chmod +x Miniconda3-latest-Linux-x86_64.sh
    ./Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda
    rm Miniconda3-latest-Linux-x86_64.sh
    echo 'export PATH="$HOME/miniconda/bin:$PATH"' >> ~/.zshrc
fi

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install zsh plugins
ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}
git clone https://github.com/MichaelAquilina/zsh-you-should-use.git $ZSH_CUSTOM/plugins/you-should-use
git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
git clone https://github.com/fdellwing/zsh-bat.git $ZSH_CUSTOM/plugins/zsh-bat

# Enable plugins in .zshrc
sed -i 's/plugins=(git)/plugins=(git sudo aws kubectx you-should-use zsh-autosuggestions zsh-syntax-highlighting zsh-bat kubectl kube-ps1 history common-aliases)/' ~/.zshrc

# Add useful zsh configurations
echo '
# zsh enhancements
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_IGNORE_ALL_DUPS    # Remove duplicates from history
setopt HIST_IGNORE_SPACE       # Ignore commands with leading space
setopt INC_APPEND_HISTORY      # Append history as commands are typed
setopt SHARE_HISTORY           # Share history between zsh sessions

# FZF integration
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Function: Automatically log in to AWS ECR after switching profiles
aws_ecr_login() {
    if [[ -z "$AWS_PROFILE" ]]; then
        echo "AWS_PROFILE is not set. Please switch to an AWS profile first using 'awsp'."
        return 1
    fi

    # Get AWS account ID dynamically
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    AWS_REGION="us-east-1" # Change this to match your region

    if [[ -n "$AWS_ACCOUNT_ID" ]]; then
        echo "Logging in to AWS ECR for account: $AWS_ACCOUNT_ID in region: $AWS_REGION..."
        aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

        if [[ $? -eq 0 ]]; then
            echo "Successfully logged in to AWS ECR!"
        else
            echo "Failed to log in to AWS ECR."
        fi
    else
        echo "Error: Unable to retrieve AWS Account ID. Make sure you are logged in to AWS."
    fi
}

# Function: Automatically set environment variables after switching EKS clusters
aws_set_cluster_env() {
    if [[ -z "$AWS_PROFILE" ]]; then
        echo "❌ AWS_PROFILE is not set. Please switch to an AWS profile first using 'awsp'."
        return 1
    fi

    echo "🔄 Fetching available EKS clusters for profile: $AWS_PROFILE..."

    # Fetch EKS cluster list
    cluster=$(aws eks list-clusters --query "clusters[]" --output text | tr '\t' '\n' | fzf --prompt "Select an EKS Cluster: ")

    if [[ -n "$cluster" ]]; then
        echo "🔄 Updating kubeconfig for cluster: $cluster..."

        # Retrieve AWS Account ID dynamically
        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null)

        if [[ -z "$AWS_ACCOUNT_ID" ]]; then
            echo "❌ Failed to retrieve AWS Account ID! Make sure you are logged in with 'aws sso login'."
            return 1
        fi

        # Retrieve AWS Region from EKS cluster ARN
        AWS_REGION=$(aws eks describe-cluster --name "$cluster" --query "cluster.arn" --output text | cut -d':' -f4)

        if [[ -z "$AWS_REGION" || "$AWS_REGION" == "None" ]]; then
            echo "❌ Failed to retrieve AWS Region for cluster $cluster!"
            return 1
        fi

        aws eks update-kubeconfig --region "$AWS_REGION" --name "$cluster"

        # Set KUBECONFIG dynamically per AWS account and cluster
        export KUBECONFIG="$HOME/.kube/config-$AWS_ACCOUNT_ID-$cluster"
        echo "✅ Using KUBECONFIG: $KUBECONFIG"

        # Set default Kubernetes namespace (Modify as needed)
        export KUBE_NAMESPACE="default"
        echo "✅ Using Kubernetes namespace: $KUBE_NAMESPACE"

        # Save AWS_REGION globally
        export AWS_REGION
        export AWS_ACCOUNT_ID

        # Retrieve Kubernetes version
        K8S_VERSION=$(aws eks describe-cluster --name "$cluster" --query "cluster.version" --output text)
        echo "🔄 Kubernetes version for cluster $cluster: $K8S_VERSION"

        # Install the correct version of kubectl
        echo "🔄 Installing kubectl version $K8S_VERSION..."
        curl -LO "https://dl.k8s.io/release/v$K8S_VERSION/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl

        # Install k9s based on Kubernetes version
        if [[ $(echo "$K8S_VERSION >= 1.26" | bc -l) -eq 1 ]]; then
            echo "🔄 Installing k9s for Kubernetes version $K8S_VERSION..."
            wget https://github.com/derailed/k9s/releases/download/v0.32.7/k9s_linux_amd64.deb
            sudo apt install ./k9s_linux_amd64.deb
            rm k9s_linux_amd64.deb
        else
            echo "❌ k9s not installed. Kubernetes version is below 1.26."
        fi

    else
        echo "❌ No cluster selected."
    fi
}

aws_switch_sso_profile() {
    selected_profile=$(aws configure list-profiles | fzf --prompt "Select AWS SSO Profile: ")

    if [[ -n "$selected_profile" ]]; then
        export AWS_PROFILE="$selected_profile"
        echo "✅ Switched to AWS Profile: $AWS_PROFILE"

        # Authenticate with AWS SSO
        echo "🔄 Authenticating with AWS SSO..."
        aws sso login

        # Verify session credentials and fetch AWS Account ID
        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null)

        if [[ -z "$AWS_ACCOUNT_ID" ]]; then
            echo "❌ AWS SSO login failed or unable to retrieve AWS Account ID!"
            return 1
        fi

        echo "✅ Successfully logged into AWS SSO: $AWS_PROFILE (Account ID: $AWS_ACCOUNT_ID)"

#        # Auto-login to AWS ECR
#        aws_ecr_login

    else
        echo "❌ No profile selected."
    fi
}

# Aliases for Quick Profile & Kubernetes Switching
alias awsp="aws_switch_sso_profile"
alias aws-kube="aws_set_cluster_env"
alias ecr-login="aws_ecr_login"

' >> ~/.zshrc

# Set Zsh as default shell by modifying /etc/passwd
sudo sed -i 's|/bin/bash|/bin/zsh|' /etc/passwd

# Reload shell
exec zsh -l