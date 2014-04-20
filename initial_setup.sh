add_authorized_ssh_key() {
  $user=$1

  echo "Adding the authorized keys to user: $user"
  mkdir -p "/home/$user/.ssh"
  touch "/home/$user/.ssh/authorized_keys"
  echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsdnNYrjCYD2yWzm+QvVvbDvbEVldE93WluxexwRJsFGxUszyPpcMng0hy38UdS+7Qd3mzPS1q2YvgGnNxq7OCdsNfbjCgXfEbwD9zc7P6yN6wn+1tNp1zzlz8jHLFUbvMG3nw6JHt28EwvJEe190qFBZN1vvLjVatFFsSLUuuF6uTOkYGuNErLD39C6QB04j+RDxCF6tI5IQrefTcz82oQKbRTFVDbEKTLw7UCQeM5jKn4PyiFs8WFqTvdDlcwxs3XPU7hXGwvdpHn83TbFBws7ryfHtjnknORqX77QseJQ3M3vNd4/WcRkJrof1H2NdrYYl5BQH0G/efvuERgCbl asherlc@asherlc.com" > "/home/$user/.ssh/authorized_keys"
  echo "\033[32m Keys added\033[0m\n"
}

echo "Installing necessary packages.\n"
apt-get -y update
apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y install sudo git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev postgresql postgresql-contrib nginx libpq-dev
echo "\033[32m Packages installed\033[0m\n"

echo "Creating deploy user\n"
user_password=$(date +%s | sha256sum | base64 | head -c 8)
useradd deploy -p $user_password

read -p "Enter the app's name: " app_name
echo "Creating app folder and deploy user home folder\n"
mkdir -p "/var/www/$app_name"
chown deploy "/var/www/$app_name"
mkdir -p /home/deploy

read -p "Enter the app's needed Ruby version: " ruby_version

echo "Installing rbenv"
git clone https://github.com/sstephenson/rbenv.git /home/deploy/.rbenv
git clone https://github.com/sstephenson/ruby-build.git /home/deploy/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> /home/deploy/.bashrc
echo 'eval "$(rbenv init -)"' >> /home/deploy/.bashrc
echo "Installing requested Ruby version. This might take a while.\n"
/home/deploy/.rbenv/bin/rbenv install $ruby_version
/home/deploy/.rbenv/bin/rbenv global $ruby_version
/home/deploy/.rbenv/bin/rbenv rehash
/home/deploy/.rbenv/shims/gem install bundler
echo "\033[32m rbenv, Ruby and Bundler installed\033[0m\n"

read -p "Enter the app's name: " app_name
underscored_app_name=$(echo "$app_name"  | sed 's/-/_/g')

echo "Setting up nginx configurations\n"
read -p "Enter the primary domain name (ex: myapp.com): " primary_domain
nginx_config_file_path="/etc/nginx/sites-available/$primary_domain"
cp "${PWD}/templates/nginx_config" $nginx_config_file_path
read -p "Enter the alias domains (ex: myapp.org myapp.net myapp.mobi): " domain_aliases
sed -i "s/<app-name>/$app_name/g" $nginx_config_file_path
sed -i "s/<app_name>/$underscored_app_name/g" $nginx_config_file_path
sed -i "s/<primary_domain>/$primary_domain/g" $nginx_config_file_path
sed -i "s/<domain_aliases>/$domain_aliases/g" $nginx_config_file_path
sudo ln -s $nginx_config_file_path "/etc/nginx/sites-enabled/$primary_domain"
mkdir -p "/var/log/nginx/$primary_domain"
echo "\033[32m nginx configured and ready to go.\033[0m\n"

echo "Setting up Postgres DB\n"
/usr/local/pgsql/bin/createuser deploy
/usr/local/pgsql/bin/createdb $app_name -O deploy

echo "Setting up SSH keys\n"
echo "Supply the keygen generator with a blank password: "
ssh-keygen -f /home/deploy/.ssh/id_rsa -t rsa -N ''
echo "\033[33m Paste the following into the GitHub or GitLab deploy keys section:\033[0m\n"
cat /home/deploy/.ssh/id_rsa.pub
read -p "Press enter when you've copied the key over and are ready to continue." continue_confirmation

echo "\033[33m Enabling SSH connection to the Git repository. Please accept the connection when prompted.\033[0m\n"
runuser -l deploy -c "ssh -T git@github.com"

add_authorized_ssh_key() root
add_authorized_ssh_key() deploy

chown -R deploy /home/deploy
