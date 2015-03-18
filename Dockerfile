FROM ubuntu:14.04

ENV DEBIAN_FRONTEND noninteractive

# Install tools and dependencies
RUN apt-get --quiet --quiet update
RUN apt-get --assume-yes upgrade
RUN apt-get install --quiet --assume-yes python-dev python-setuptools python-pip libssl-dev libxml2-dev libxslt1-dev build-essential git imagemagick sqlite3 software-properties-common curl wget lsof language-pack-en pwgen couchdb
RUN update-locale LANG=en_US.UTF-8

# Install NodeJS and NPM
RUN cd /tmp && \
wget http://nodejs.org/dist/v0.10.26/node-v0.10.26.tar.gz && \
tar xvzf node-v0.10.26.tar.gz && \
rm -f v0.10.26.tar.gz && \
cd node-v0.10.26 && \
./configure && \
CXX="g++ -Wno-unused-local-typedefs" make && \
CXX="g++ -Wno-unused-local-typedefs" make install && \
cd /tmp && \
rm -rf /tmp/node-v* && \
npm install -g npm

# Create Cozy users
RUN useradd -M cozy
RUN useradd -M cozy-data-system
RUN useradd -M cozy-home

# Configure CouchDB
RUN mkdir /etc/cozy
RUN pwgen -1 > /etc/cozy/couchdb.login
RUN pwgen -1 >> /etc/cozy/couchdb.login
RUN chown cozy-data-system /etc/cozy/couchdb.login
RUN chmod 640 /etc/cozy/couchdb.login
RUN mkdir /var/run/couchdb
RUN chown -hR couchdb /var/run/couchdb
RUN su - couchdb -c 'couchdb -b' && \
sleep 5 && while ! curl -s 127.0.0.1:5984; do sleep 5; done && \
curl -s -X PUT 127.0.0.1:5984/_config/admins/$(head -n1 /etc/cozy/couchdb.login) -d "\"$(tail -n1 /etc/cozy/couchdb.login)\""

# Install supevisord
RUN pip install supervisor
ADD supervisor/supervisord.conf /etc/supervisord.conf
RUN mkdir -p /var/log/supervisor
RUN chmod 777 /var/log/supervisor
RUN /usr/local/bin/supervisord -c /etc/supervisord.conf

# Install CoffeeScript and Cozy Monitor via NPM
RUN npm install -g coffee-script cozy-monitor

# Install Cozy Controller via NPM
RUN npm install -g cozy-controller

# Install Cozy Indexer and its requirements via PIP
RUN mkdir -p /usr/local/cozy-indexer
RUN cd /usr/local/cozy-indexer && git clone https://github.com/cozy/cozy-data-indexer.git

RUN cd /usr/local/cozy-indexer/cozy-data-indexer && \
pip install virtualenv && \
virtualenv --quiet /usr/local/cozy-indexer/cozy-data-indexer/virtualenv && \
. ./virtualenv/bin/activate && \
pip install  -r /usr/local/cozy-indexer/cozy-data-indexer/requirements/common.txt

RUN chown -R cozy:cozy /usr/local/cozy-indexer

# Start CouchDB, controller, indexer, then install the DS / Home / Proxy
ENV NODE_ENV production
RUN su - couchdb -c 'couchdb -b' && \
sleep 5 && while ! curl -s 127.0.0.1:5984; do sleep 5; done && \
/usr/local/lib/node_modules/cozy-controller/bin/cozy-controller & \
sleep 5 && while ! curl -s 127.0.0.1:9002; do sleep 5; done && \
cd /usr/local/cozy-indexer/cozy-data-indexer && \
. ./virtualenv/bin/activate && \
/usr/local/cozy-indexer/cozy-data-indexer/virtualenv/bin/python server.py & \
sleep 5 && while ! curl -s 127.0.0.1:9102; do sleep 5; done && \
cozy-monitor install data-system && \
cozy-monitor install home && \
cozy-monitor install proxy

# Install a late version of Nginx
RUN apt-get install --quiet --assume-yes python-software-properties
RUN add-apt-repository --yes ppa:nginx/stable
RUN apt-get -qq update
RUN apt-get install --quiet --assume-yes nginx
RUN nginx -t

# Generate the SSL certificate and the DH parameter
RUN chown -hR cozy /etc/cozy
RUN openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/cozy/server.key -out /etc/cozy/server.crt -days 365 -subj '/CN=localhost'
RUN openssl dhparam -out /etc/cozy/dh2048.pem -outform PEM -2 2048
RUN chown cozy:cozy /etc/cozy/server.key
RUN chmod 600 /etc/cozy/server.key

# Configure Nginx and check configuration by restarting the service
ADD nginx/nginx.conf /etc/nginx/nginx.conf
ADD nginx/cozy.conf /etc/nginx/sites-available/cozy.conf
RUN chmod 0644 /etc/nginx/sites-available/cozy.conf
RUN rm /etc/nginx/sites-enabled/default
RUN ln -s /etc/nginx/sites-available/cozy.conf /etc/nginx/sites-enabled/cozy.conf
RUN nginx -t

# Install Postfix with default parameters
# TODO: Change mydomain.net?
RUN echo "postfix postfix/mailname string mydomain.net" | debconf-set-selections
RUN echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
RUN echo "postfix postfix/destinations string mydomain.net, localhost.localdomain, localhost " | debconf-set-selections
RUN apt-get install --quiet --assume-yes postfix
RUN postfix check

# Copy supervisord configuration files
ADD supervisor/cozy-controller.conf /etc/supervisor/conf.d/cozy-controller.conf
ADD supervisor/cozy-indexer.conf /etc/supervisor/conf.d/cozy-indexer.conf
ADD supervisor/couchdb.conf /etc/supervisor/conf.d/couchdb.conf
ADD supervisor/nginx.conf /etc/supervisor/conf.d/nginx.conf
ADD supervisor/postfix.conf /etc/supervisor/conf.d/postfix.conf
RUN chmod 0644 /etc/supervisor/conf.d/*

# Clean APT cache for a lighter image
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


EXPOSE 80 443

VOLUME ["/usr/local/var/lib/couchdb", "/etc/cozy", "/usr/local/cozy"]

CMD [ "/usr/local/bin/supervisord", "-n", "-c", "/etc/supervisord.conf" ]
