FROM ubuntu:trusty

ENV DEBIAN_FRONTEND noninteractive

# install_tools
RUN apt-get --quiet --quiet update
RUN apt-get --assume-yes upgrade
RUN apt-get install --quiet --assume-yes python-dev python-setuptools python-pip libssl-dev libxml2-dev libxslt1-dev build-essential git imagemagick sqlite3 software-properties-common curl wget
#RUN curl -o - https://bootstrap.pypa.io/ez_setup.py -O - | python
#RUN curl -o - https://bootstrap.pypa.io/get-pip.py | python -

# install_node10
RUN apt-get install --quiet --assume-yes nodejs npm && ln -s /usr/bin/nodejs /usr/local/bin/node

# install_couchdb
RUN apt-get install --quiet --assume-yes couchdb

# install_postfix
#echo "postfix postfix/mailname string mydomain.net" | debconf-set-selections
#echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
#echo "postfix postfix/destinations string mydomain.net, localhost.localdomain, localhost " | debconf-set-selections
#apt-get install --quiet --assume-yes postfix
#service postfix start

# create_cozy_user
RUN useradd -M cozy && useradd -M cozy-data-system && useradd -M cozy-home

# config_couchdb
RUN mkdir -p /var/run/couchdb && chown couchdb:couchdb /var/run/couchdb && su - couchdb -c 'couchdb -b' && sleep 30 && curl -X PUT http://127.0.0.1:5984/_config/admins/cozy -d '"cozypass"' && su - couchdb -c 'couchdb -k'
RUN mkdir /etc/cozy && chown cozy "/etc/cozy" && /bin/echo -e "cozy\ncozypass" > /etc/cozy/couchdb.login
RUN chown cozy-data-system "/etc/cozy/couchdb.login"
RUN chmod 700 "/etc/cozy/couchdb.login"
ADD couchdb.conf /etc/supervisor/conf.d/couchdb.conf

# Install npm packages
RUN npm install -g coffee-script cozy-monitor cozy-controller

# install_indexer
RUN mkdir -p "/usr/local/cozy-indexer" && cd /usr/local/cozy-indexer && git clone https://github.com/cozy/cozy-data-indexer.git
RUN cd /usr/local/cozy-indexer/cozy-data-indexer && pip install virtualenv && virtualenv --quiet /usr/local/cozy-indexer/cozy-data-indexer/virtualenv && . ./virtualenv/bin/activate && pip install  -r /usr/local/cozy-indexer/cozy-data-indexer/requirements/common.txt
RUN chown -R cozy:cozy /usr/local/cozy-indexer
ADD cozy-indexer.conf /etc/supervisor/conf.d/cozy-indexer.conf
RUN chmod 0644 "/etc/supervisor/conf.d/cozy-indexer.conf"

RUN pip install supervisor
ADD supervisord.conf /etc/supervisord.conf
RUN mkdir -p /var/log/supervisor && chmod 777 /var/log/supervisor
RUN /usr/local/bin/supervisord -c /etc/supervisord.conf

# Install cozy stack
ADD cozy-controller.conf /etc/supervisor/conf.d/cozy-controller.conf
RUN chmod 0644 "/etc/supervisor/conf.d/cozy-controller.conf"
RUN /usr/bin/python /usr/local/bin/supervisord -c /etc/supervisord.conf && sleep 5 && cozy-monitor status ; cozy-monitor install data-system && cozy-monitor install home && cozy-monitor install proxy && supervisorctl stop all

# # install_nginx
RUN apt-get install --quiet --assume-yes python-software-properties
RUN add-apt-repository --yes  ppa:nginx/stable
RUN apt-get --quiet --quiet update
RUN apt-get install --quiet --assume-yes nginx
ADD cozy.conf /etc/nginx/sites-available/cozy.conf
RUN chmod 0644 "/etc/nginx/sites-available/cozy.conf" && rm /etc/nginx/sites-enabled/default
RUN ln -s /etc/nginx/sites-available/cozy.conf /etc/nginx/sites-enabled/cozy.conf
##RUN service nginx reload && service nginx restart

# create_cert
RUN mkdir -p /etc/nginx/certs && chmod 700 /etc/nginx/certs
RUN cd /etc/nginx/certs && openssl req -x509 -nodes -newkey rsa:2048 -keyout server.key -out server.crt -days 365 -subj '/CN=localhost' && chmod 400 server.key && chmod 444 server.crt
ADD nginx.conf /etc/nginx/nginx.conf
ADD supervisor-nginx.conf /etc/supervisor/conf.d/nginx.conf
RUN chmod 0644 "/etc/supervisor/conf.d/cozy-indexer.conf"

EXPOSE 80 443

VOLUME ["/usr/local/var/lib/couchdb", "/etc/cozy", "/usr/local/cozy"]

CMD [ "/usr/bin/python", "/usr/local/bin/supervisord", "-n", "-c", "/etc/supervisord.conf" ]
