FROM ubuntu:14.04

ENV DEBIAN_FRONTEND noninteractive

# Install Cozy tools and dependencies.
RUN echo "deb http://ppa.launchpad.net/nginx/stable/ubuntu trusty main" >> /etc/apt/sources.list \
 && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C300EE8C \
 && apt-get update --quiet \
 && apt-get install --quiet --yes \
  build-essential \
  couchdb \
  curl \
  git \
  imagemagick \
  language-pack-en \
  libffi6 \
  libffi-dev \
  libssl-dev \
  libxml2-dev \
  libxslt1-dev \
  libjpeg-dev \
  lsof \
  nginx \
  postfix \
  pwgen \
  python-dev \
  python-pip \
  python-setuptools \
  python-software-properties \
  software-properties-common \
  sqlite3 \
  wget
RUN update-locale LANG=en_US.UTF-8
RUN pip install \
  supervisor \
  virtualenv

# Install NodeJS 4.2.X LTS
RUN curl -sL https://deb.nodesource.com/setup_4.x | bash -
RUN apt-get install -y nodejs

# Install CoffeeScript, Cozy Monitor and Cozy Controller via NPM.
RUN npm install -g \
  coffee-script \
  cozy-controller \
  cozy-monitor

# Create Cozy users, without home directories.
RUN useradd -M cozy \
 && useradd -M cozy-data-system \
 && useradd -M cozy-home

# Configure CouchDB.
RUN mkdir /etc/cozy \
 && chown -hR cozy /etc/cozy
RUN pwgen -1 > /etc/cozy/couchdb.login \
 && pwgen -1 >> /etc/cozy/couchdb.login \
 && chown cozy-data-system /etc/cozy/couchdb.login \
 && chmod 640 /etc/cozy/couchdb.login
RUN mkdir /var/run/couchdb \
 && chown -hR couchdb /var/run/couchdb \
 && su - couchdb -c 'couchdb -b' \
 && sleep 5 \
 && while ! curl -s 127.0.0.1:5984; do sleep 5; done \
 && curl -s -X PUT 127.0.0.1:5984/_config/admins/$(head -n1 /etc/cozy/couchdb.login) -d "\"$(tail -n1 /etc/cozy/couchdb.login)\""

# Configure Supervisor.
ADD supervisor/supervisord.conf /etc/supervisord.conf
RUN mkdir -p /var/log/supervisor \
 && chmod 777 /var/log/supervisor \
 && /usr/local/bin/supervisord -c /etc/supervisord.conf

# Start up background services and install the Cozy platform apps.
ENV NODE_ENV production
RUN su - couchdb -c 'couchdb -b' \
 && sleep 5 \
 && while ! curl -s 127.0.0.1:5984; do sleep 5; done \
 && cozy-controller & sleep 5 \
 && while ! curl -s 127.0.0.1:9002; do sleep 5; done \
 && cozy-monitor install data-system \
 && cozy-monitor install home \
 && cozy-monitor install proxy \
 && curl -X POST http://localhost:9103/api/instance -H "Content-Type: application/json" -d '{"background":"background-07"}' \
 && for app in calendar contacts photos emails files sync; do \
   cozy-monitor install $app; \
 done

# Configure Nginx and check its configuration by restarting the service.
ADD nginx/nginx.conf /etc/nginx/nginx.conf
ADD nginx/cozy /etc/nginx/sites-available/cozy
ADD nginx/cozy-ssl /etc/nginx/sites-available/cozy-ssl
RUN chmod 0644 /etc/nginx/sites-available/cozy /etc/nginx/sites-available/cozy-ssl \
 && rm /etc/nginx/sites-enabled/default \
 && ln -s /etc/nginx/sites-available/cozy /etc/nginx/sites-enabled/cozy
RUN nginx -t

# Configure Postfix with default parameters.
# TODO: Change mydomain.net?
RUN echo "postfix postfix/mailname string mydomain.net" | debconf-set-selections \
 && echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections \
 && echo "postfix postfix/destinations string mydomain.net, localhost.localdomain, localhost " | debconf-set-selections \
 && cp /etc/services /var/spool/postfix/etc/ \
 && cp /etc/resolv.conf /var/spool/postfix/etc \
 && postfix check

# Import Supervisor configuration files.
ADD supervisor/cozy-controller.conf /etc/supervisor/conf.d/cozy-controller.conf
ADD supervisor/cozy-init.conf /etc/supervisor/conf.d/cozy-init.conf
ADD supervisor/couchdb.conf /etc/supervisor/conf.d/couchdb.conf
ADD supervisor/nginx.conf /etc/supervisor/conf.d/nginx.conf
ADD supervisor/postfix.conf /etc/supervisor/conf.d/postfix.conf
ADD cozy-init /etc/init.d/cozy-init
RUN chmod 0644 /etc/supervisor/conf.d/*

# Clean APT cache for a lighter image.
RUN apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 80 443

VOLUME ["/var/lib/couchdb", "/etc/cozy", "/usr/local/cozy", "/usr/local/var/cozy/"]

CMD [ "/usr/local/bin/supervisord", "-n", "-c", "/etc/supervisord.conf" ]
