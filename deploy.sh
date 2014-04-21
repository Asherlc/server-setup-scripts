# read -p "Enter the remote address: " remote_host
remote_host=www.vocalem.com

ssh "root@$remote_host" mkdir -p /home/root/server-setup-scripts
rsync -azrvv --recursive --progress --exclude='deploy.sh' --exclude="README*" --exclude=".*" . "root@$remote_host:/home/root/server-setup-scripts"

ssh -t "root@$remote_host" 'sudo sh /home/root/server-setup-scripts/initial_setup.sh -i install_ruby'
