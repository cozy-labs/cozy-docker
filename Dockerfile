FROM ubuntu

ENV DEBIAN_FRONTEND noninteractive

# install_tools
RUN apt-get --quiet --quiet update
RUN apt-get --assume-yes upgrade
RUN apt-get install --quiet --assume-yes python-dev python-setuptools python-pip libssl-dev libxml2-dev libxslt1-dev build-essential git imagemagick sqlite3 software-properties-common curl wget
RUN curl -o - https://bootstrap.pypa.io/ez_setup.py -O - | python
RUN curl -o - https://bootstrap.pypa.io/get-pip.py | python -

# install_node10
RUN apt-get install --quiet --assume-yes nodejs npm

# install_couchdb
RUN apt-get install --quiet --assume-yes couchdb

# install_postfix
#echo "postfix postfix/mailname string mydomain.net" | debconf-set-selections
#echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
#echo "postfix postfix/destinations string mydomain.net, localhost.localdomain, localhost " | debconf-set-selections
#apt-get install --quiet --assume-yes postfix
#service postfix start

# create_cozy_user
RUN useradd -M cozy
RUN useradd -M cozy-data-system
RUN useradd -M cozy-home

# config_couchdb
RUN mkdir /etc/cozy && echo -e "cozy\ncozypass" > /etc/cozy/couchdb.login
RUN chown cozy-data-system "/etc/cozy/couchdb.login"
RUN chmod 700 "/etc/cozy/couchdb.login"

# install_monitor
RUN npm install -g coffee-script cozy-monitor

# install_controller
#curl -X GET http://127.0.0.1:9002/
RUN npm install -g cozy-controller
#umask
ADD cozy-controller.conf /etc/supervisor/conf.d/cozy-controller.conf
RUN chmod 0644 "/etc/supervisor/conf.d/cozy-controller.conf"

# install_indexer
RUN mkdir -p "/usr/local/cozy-indexer" && cd /usr/local/cozy-indexer && git clone https://github.com/cozy/cozy-data-indexer.git
RUN cd /usr/local/cozy-indexer/cozy-data-indexer && pip install virtualenv && virtualenv --quiet /usr/local/cozy-indexer/cozy-data-indexer/virtualenv && . ./virtualenv/bin/activate && pip install  -r /usr/local/cozy-indexer/cozy-data-indexer/requirements/common.txt
RUN chown -R cozy:cozy /usr/local/cozy-indexer
#umask
ADD cozy-indexer.conf /etc/supervisor/conf.d/cozy-indexer.conf
RUN chmod 0644 "/etc/supervisor/conf.d/cozy-indexer.conf"

# install_data_system
RUN su - couchdb -c 'couchdb -b' && sleep 30 && NODE_ENV="production" /usr/local/lib/node_modules/cozy-controller/bin/cozy-controller & sleep 35 && cd /usr/local/cozy-indexer/cozy-data-indexer && . ./virtualenv/bin/activate && /usr/local/cozy-indexer/cozy-data-indexer/virtualenv/bin/python server.py & sleep 5 && cozy-monitor install data-system && cozy-monitor install home && cozy-monitor install proxy && ps faux && pgrep node | xargs kill ; pgrep python | xargs kill ; su - couchdb -c 'couchdb -k'

# create_cert
RUN chown cozy "/etc/cozy"
RUN cd /etc/cozy && openssl genrsa -out ./server.key 1024
RUN cd /etc/cozy && openssl req -new -x509 -days 3650 -key ./server.key -out ./server.crt  -batch && chmod 640 server.key && chown cozy:cozy ./server.key
#RUN cd /etc/cozy && chmod 640 server.key && chown cozy:ssl-cert ./server.key

# install_nginx
RUN apt-get install --quiet --assume-yes python-software-properties
RUN add-apt-repository --yes  ppa:nginx/stable
RUN apt-get --quiet --quiet update
RUN apt-get install --quiet --assume-yes nginx
RUN service nginx start
#umask
ADD cozy.conf /etc/nginx/sites-available/cozy.conf
RUN chmod 0644 "/etc/nginx/sites-available/cozy.conf" && rm /etc/nginx/sites-enabled/default
RUN ln -s /etc/nginx/sites-available/cozy.conf /etc/nginx/sites-enabled/cozy.conf
##RUN service nginx reload && service nginx restart

# restart_cozy
##RUN cozy-monitor restart data-system && cozy-monitor restart home && cozy-monitor restart proxy

RUN apt-get install --quiet --assume-yes lsof

RUN pip install supervisor
ADD supervisord.conf /etc/supervisord.conf
RUN mkdir -p /var/log/supervisor && chmod 777 /var/log/supervisor
RUN /usr/local/bin/supervisord -c /etc/supervisord.conf

EXPOSE 22 80 443 9104

#VOLUME ["/usr/local/var/lib/couchdb", "/etc/cozy", "/usr/local/cozy"]

CMD [ "/usr/bin/python", "/usr/local/bin/supervisord", "-n", "-c", "/etc/supervisord.conf" ]
