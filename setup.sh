# Source: https://docs.sentry.io/server/installation/python/

# Requirements
apt-get update && apt-get upgrade -y
apt-get install -y  python-setuptools python-pip python-dev libxslt1-dev libxml2-dev libz-dev libffi-dev libssl-dev libpq-dev libyaml-dev postgresql nginx-full supervisor redis-server

#Create a sentry user, IMPORTANT to run sentry web and worker
sudo adduser sentry
sudo adduser sentry sudo

# Install virtualenv via pip:
pip install -U virtualenv

# Change user root user to sentry
sudo su - sentry

# 3 . Select a location for the environment and configure it with virtualenv. As exemplified, the location used is /www/sentry:
virtualenv /www/sentry/

# Activate the virtualenv now:
source /www/sentry/bin/activate
# Note: Activating the environment will adjust the PATH and pip will install into the virtualenv by default. use: deactivate to exit.


# Now that the environment is setup, install sentry on the machine. Again pip is used:
pip install -U sentry

# Create database and Enable citext extension as it is required for the installation (the database creation will fail is this step is skipped):
sudo su - postgres
psql -d template1 -U postgres
create extension citext;
\q

createdb sentrydb
createuser sentry --pwprompt
psql -d template1 -U postgres
GRANT ALL PRIVILEGES ON DATABASE sentrydb to sentry;
ALTER USER sentry WITH SUPERUSER;
\q


# Initialize Sentry:
sentry init /etc/sentry
#This command will create the configuration files in the directory /etc/sentry.

# Edit the file /etc/sentry/sentry.conf.py and add the database credentials: It should look like the following example:

DATABASES = {
    'default': {
    'ENGINE': 'sentry.db.postgres',
    'NAME': 'sentrydb',
    'USER': 'sentry',
    'PASSWORD': 'sentry',
    'HOST': 'localhost',
    'PORT': '5432',
    'AUTOCOMMIT': True,
    'ATOMIC_REQUESTS': False,
    }
}

# In order to receive mails from our Sentry instance, configure the e-mail in the file /etc/sentry/config.yml:
mail.from: 'sentry@localhost'
mail.host: 'localhost'
mail.port: 25
mail.username: ''
mail.password: ''
mail.use-tls: false

# Make sure there is some swap on the server, as the sentry upgrade first run WILL fail with less than 4GB of RAM!
# see https://github.com/getsentry/sentry/issues/8862#issuecomment-447259743

#  Initialize the database by running the upgrade function of Sentry:
SENTRY_CONF=/etc/sentry sentry upgrade

# Edit the file /etc/nginx/sites-enabled/default and put the following content in it:

server {
    listen 80 default_server;
    server_name sentry.local;

    location / {
    proxy_pass         http://localhost:9000;
    proxy_redirect     off;

    proxy_set_header   Host              $host;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
    }

}

# Save the file and restart your Sentry server:
service nginx restart

#log out from sentry user IMPORTANT.
exit

# Configure systemd to start services: https://docs.sentry.io/server/installation/python/#configure-systemd
# Don't forget to append "-b localhost" to the ExecStart for sentry-web or the sentry web server will be available to everyone on port 9000!

# Install dehydrated and configure it to create a certificate for your domain in nginx:

server {
    listen 443 ssl;
    server_name sentry.xxx;

    # Comment these line before you get the certificate for the first time
    ssl_certificate /var/lib/dehydrated/certs/sentry.xxx/fullchain.pem;
    ssl_certificate_key /var/lib/dehydrated/certs/sentry.xxx/privkey.pem;


    location / {
        proxy_pass         http://localhost:9000;
        proxy_redirect     off;

        proxy_set_header   Host              $host;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }   


    location ^~ /.well-known/acme-challenge {
        alias /var/lib/dehydrated/acme-challenges;
    }
}

# Add domain to /etc/dehydrated/domains.txt then run "dehydrated -c"
# And add a daily cron  that does "dehydrated -c; service nginx reload"

