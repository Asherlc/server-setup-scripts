#!/usr/bin/env bash

function as_user() {
  su -l -c "$1" deploy
}

log_operation() {
  local function_name

  function_name="$1"

  echo "Starting $($function_name | sed 's/_/ /g')"
}

log_operation_finished() {
  local function_name
  local readable_function_name

  function_name="$1"
  readable_function_name=$(echo $function_name | sed 's/_/ /g')

  echo "\033[32m$readable_function_name finished\033[0m\n"
}

get_app_name() {
  if [ -z $app_name ]; then
    read -p "Enter the app's name: " app_name
  fi
}

add_authorized_ssh_key() {
  log_operation "$FUNCNAME"

  local user
  $user=$1

  echo "Adding the authorized keys to $user"
  mkdir -p "/home/$user/.ssh"
  touch "/home/$user/.ssh/authorized_keys"
  echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsdnNYrjCYD2yWzm+QvVvbDvbEVldE93WluxexwRJsFGxUszyPpcMng0hy38UdS+7Qd3mzPS1q2YvgGnNxq7OCdsNfbjCgXfEbwD9zc7P6yN6wn+1tNp1zzlz8jHLFUbvMG3nw6JHt28EwvJEe190qFBZN1vvLjVatFFsSLUuuF6uTOkYGuNErLD39C6QB04j+RDxCF6tI5IQrefTcz82oQKbRTFVDbEKTLw7UCQeM5jKn4PyiFs8WFqTvdDlcwxs3XPU7hXGwvdpHn83TbFBws7ryfHtjnknORqX77QseJQ3M3vNd4/WcRkJrof1H2NdrYYl5BQH0G/efvuERgCbl asherlc@asherlc.com" > "/home/$user/.ssh/authorized_keys"

  log_operation_finished "$FUNCNAME"
}

install_packages() {
  log_operation "$FUNCNAME"

  apt-get -y update
  apt-get -y upgrade
  apt-get -y dist-upgrade
  apt-get -y install sudo git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev postgresql postgresql-contrib nginx libpq-dev ImageMagick libmagickwand-dev graphicsmagick-libmagick-dev-compat libmagickcore-dev memcached default-jre openjdk-6-jdk solr-tomcat monit

  log_operation_finished "$FUNCNAME"
}

create_deploy_user() {
  log_operation "$FUNCNAME"

  adduser --disabled-password --gecos "" deploy

  # Grant sudo access to nginx services
  touch /etc/sudoers.d/deploy
  echo "deploy ALL=NOPASSWD: /usr/sbin/service nginx start,/usr/sbin/service nginx stop,/usr/sbin/service nginx restart" > /etc/sudoers.d/deploy

  log_operation_finished "$FUNCNAME"
}


create_directories() {
  log_operation "$FUNCNAME"

  mkdir -p "/var/www/$app_name"
  chown deploy "/var/www/$app_name"

  log_operation_finished "$FUNCNAME"
}

install_ruby() {
  local ruby_version

  log_operation "$FUNCNAME"

  # TODO: Figure out how to install rbenv on a per user basis
  read -p "Enter the app's needed Ruby version: " ruby_version

  # Installing rbenv
  as_user "git clone git://github.com/sstephenson/rbenv.git ~/.rbenv"
  as_user "echo 'export PATH=\"\$HOME/.rbenv/bin:\$PATH\"' >> ~/.profile"
  as_user "echo 'eval \"\$(rbenv init -)\"' >> ~/.profile"
  as_user "git clone git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build"
  log "Installing Ruby ${ruby_version}"
  as_user "rbenv install ${ruby_version} && rbenv rehash && rbenv global ${ruby_version}"
  as_user "echo 'gem: --no-document' > ~/.gemrc && gem i bundler"

  # Install rbenv for root user
  git clone git://github.com/sstephenson/rbenv.git ~/.rbenv
  echo 'export PATH=\"\$HOME/.rbenv/bin:\$PATH\"' >> ~/.profile
  echo 'eval \"\$(rbenv init -)\"' >> ~/.profile
  git clone git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
  log "Installing Ruby ${ruby_version}"
  rbenv install ${ruby_version} && rbenv rehash && rbenv global ${ruby_version}
  echo 'gem: --no-document' > ~/.gemrc && gem i bundler

  log_operation_finished "$FUNCNAME"
}

configure_nginx() {
  log_operation "$FUNCNAME"

  get_app_name
  underscored_app_name=$(echo "$app_name"  | sed 's/-/_/g')
  read -p "Enter the primary domain name (ex: myapp.com): " primary_domain
  nginx_config_file_path="/etc/nginx/sites-available/$primary_domain"
  cp "/usr/local/server-setup-scripts/templates/nginx_site_config" $nginx_config_file_path
  read -p "Enter the alias domains (ex: myapp.org myapp.net myapp.mobi): " domain_aliases
  sed -i "s/<app-name>/$app_name/g" $nginx_config_file_path
  sed -i "s/<app_name>/$underscored_app_name/g" $nginx_config_file_path
  sed -i "s/<primary_domain>/$primary_domain/g" $nginx_config_file_path
  sed -i "s/<domain_aliases>/$domain_aliases/g" $nginx_config_file_path
  sudo ln -s $nginx_config_file_path "/etc/nginx/sites-enabled/$primary_domain"
  mkdir -p "/var/log/nginx/$primary_domain"

  service nginx start

  log_operation_finished "$FUNCNAME"
}

configure_postgres() {
  log_operation "$FUNCNAME"

  get_app_name

  sudo -u postgres createuser --superuser $USER
  createuser deploy
  createdb -O deploy $app_name

  log_operation_finished "$FUNCNAME"
}

configure_ssh_keys() {
  log_operation "$FUNCNAME"


  echo "Supply the keygen generator with a blank password: "
  mkdir -p /home/deploy/.ssh
  ssh-keygen -f /home/deploy/.ssh/id_rsa -t rsa -N ''
  #TODO: make this run as the deploy user
  exec ssh-agent bash
  ssh-add ~/.ssh/id_rsa
  # end deploy user stuff
  echo "\033[33m Paste the following into the GitHub or GitLab deploy keys section:\033[0m\n"
  cat /home/deploy/.ssh/id_rsa.pub
  read -p "Press enter when you've copied the key over and are ready to continue." continue_confirmation
  
  echo "\033[33m Enabling SSH connection to the Git repository. Please accept the connection when prompted.\033[0m\n"
  runuser -l deploy -c "ssh -T git@github.com"
  
  add_authorized_ssh_key root
  add_authorized_ssh_key deploy

  log_operation_finished "$FUNCNAME"
}
  
while getopts "i:" opt; do
  case $opt in
    i)
      eval $OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

if [ -z $(getopts "i:" opt) ]; then
  install_packages
  create_deploy_user
  create_directories
  install_ruby
  configure_nginx
  configure_postgres
  configure_ssh_keys
fi

chown -R deploy /home/deploy
