# create a shell script that will install python3 and pip3 on fedora

# Update the package list
sudo dnf update -y
sudo dnf upgrade -y

# Install python3
sudo dnf install python3 -y

# Install pip3
sudo dnf install python3-pip -y

# Install zsh
sudo dnf install zsh -y

# Install curl
sudo dnf install curl -y

# Install git
sudo dnf install git -y

# install aws-cli
sudo dnf install aws-cli -y

# install miniconda
curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
# install miniconda
zsh Miniconda3-latest-Linux-x86_64.sh
# remove the miniconda installer
rm Miniconda3-latest-Linux-x86_64.sh

#install nodejs
sudo dnf install nodejs -y

# install npm
sudo dnf install npm -y


# install tmux
sudo dnf install tmux -y

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"


# add this to .zshrc file
echo '
# zsh essentials
HISTFILE=".histfile"             # Save 100000 lines of history
HISTSIZE=100000
SAVEHIST=100000
setopt BANG_HIST                 # Treat the "!" character specially during expansion.
setopt EXTENDED_HISTORY          # Write the history file in the ":start:elapsed;command" format.
setopt INC_APPEND_HISTORY        # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_IGNORE_DUPS          # Don"t record an entry that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS      # Delete old recorded entry if new entry is a duplicate.
setopt HIST_IGNORE_SPACE         # Don"t record an entry starting with a space.
' >> ~/.zshrc

# install rg
sudo dnf install ripgrep -y

# install bat
sudo dnf install bat -y

# Install zsh-you-should-use
git clone https://github.com/MichaelAquilina/zsh-you-should-use.git $ZSH_CUSTOM/plugins/you-should-use
# Add the plugin to the list of plugins for Oh My Zsh to load (inside ~/.zshrc):
plugins=([plugins...] you-should-use)

# Install zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
plugins=( [plugins...] zsh-autosuggestions)

# Install zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
plugins=( [plugins...] zsh-syntax-highlighting)

# install fzf
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install
eval "$(fzf --zsh)"

git clone https://github.com/lincheney/fzf-tab-completion.git
source ~/fzf-tab-completion/zsh/fzf-zsh-completion.sh
bindkey '^I' fzf_completion

## install pycharm in fedora by downloading the tar file from the website
#curl -O https://download.jetbrains.com/python/pycharm-professional-2023.3.5.tar.gz
## extract the tar file
#tar -xvf pycharm-professional-2023.3.5.tar.gz
## run the pycharm.sh file
## cd pycharm-2023.3.5/bin
## create a desktop entry for pycharm
#touch ~/.local/share/applications/pycharm.desktop
#echo '
#[Desktop Entry]
#Name=PyCharm
#Comment=PyCharm
#Exec=/home/khaspur_/pycharm-2023.3.5/bin/pycharm.sh
#Icon=/home/khaspur_/pycharm-2023.3.5/bin/pycharm.png
#Terminal=false
#Type=Application
#Categories=Development;
#' >> ~/.local/share/applications/pycharm.desktop
## make the desktop entry executable
#chmod +x ~/.local/share/applications/pycharm.desktop
## add pycharm to the path
#sudo ln -s /home/khaspur_/pycharm-2023.3.5/bin/pycharm.sh /usr/bin/pycharm









