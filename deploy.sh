# read -p "Enter the remote address: " remote_host
remote_host=www.vocalem.com

rsync -azrvv --recursive --progress --exclude='deploy.sh' --exclude="README*" --exclude=".*" . "root@$remote_host:/usr/local/server-setup-scripts"

ssh -t "root@$remote_host" 'sudo sh /usr/local/server-setup-scripts/initial_setup.sh'
