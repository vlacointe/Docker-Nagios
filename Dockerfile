FROM ubuntu:16.04
MAINTAINER Vincent Lacointe <vlacointe@gmail.com>

ENV NAGIOS_HOME			/opt/nagios
ENV NAGIOS_USER			nagios
ENV NAGIOS_GROUP		nagios
ENV NAGIOS_CMDUSER		nagios
ENV NAGIOS_CMDGROUP		nagios
ENV NAGIOS_FQDN			nagios.example.com
ENV NAGIOSADMIN_USER		nagiosadmin
ENV NAGIOSADMIN_PASS		nagios
ENV APACHE_RUN_USER		nagios
ENV APACHE_RUN_GROUP		nagios
ENV NAGIOS_TIMEZONE		UTC
ENV DEBIAN_FRONTEND		noninteractive
ENV NG_NAGIOS_CONFIG_FILE	${NAGIOS_HOME}/etc/nagios.cfg
ENV NG_CGI_DIR			${NAGIOS_HOME}/sbin
ENV NG_WWW_DIR			${NAGIOS_HOME}/share/nagiosgraph
ENV NG_CGI_URL			/cgi-bin


RUN	sed -i 's/universe/universe multiverse/' /etc/apt/sources.list	&& \
	echo postfix postfix/main_mailer_type string "'Internet Site'" | debconf-set-selections && \
	echo postfix postfix/mynetworks string "127.0.0.0/8" | debconf-set-selections && \
	echo postfix postfix/mailname string ${NAGIOS_FQDN} | debconf-set-selections && \
	apt-get update && apt-get install -y				\
		iputils-ping						\
		netcat							\
		dnsutils						\
		build-essential						\
		automake						\
		autoconf						\
		gettext							\
		m4							\
		gperf							\
		snmp							\
		snmpd							\
		snmp-mibs-downloader					\
		php-cli							\
		php-gd							\
		libgd2-xpm-dev						\
		apache2							\
		apache2-utils						\
		libapache2-mod-php					\
		runit							\
		unzip							\
		bc							\
		postfix							\
		rsyslog							\
		bsd-mailx						\
		libnet-snmp-perl					\
		git							\
		libssl-dev						\
		libcgi-pm-perl						\
		librrds-perl						\
		libgd-gd2-perl						\
		libnagios-object-perl					\
		libnagios-plugin-perl					\
		fping							\
		libfreeradius-client-dev				\
		libnet-snmp-perl					\
		libnet-xmpp-perl					\
		parallel						\
		libcache-memcached-perl					\
		libdbd-mysql-perl					\
		libdbi-perl						\
		libnet-tftp-perl					\
		libredis-perl						\
		libswitch-perl						\
		libwww-perl							\
		libjson-perl					&&	\
		apt-get clean

RUN	( egrep -i "^${NAGIOS_GROUP}"    /etc/group || groupadd $NAGIOS_GROUP    )				&&	\
	( egrep -i "^${NAGIOS_CMDGROUP}" /etc/group || groupadd $NAGIOS_CMDGROUP )
RUN	( id -u $NAGIOS_USER    || useradd --system -d $NAGIOS_HOME -g $NAGIOS_GROUP    $NAGIOS_USER    )	&&	\
	( id -u $NAGIOS_CMDUSER || useradd --system -d $NAGIOS_HOME -g $NAGIOS_CMDGROUP $NAGIOS_CMDUSER )

RUN	cd /tmp							&&	\
	git clone https://github.com/multiplay/qstat.git	&&	\
	cd qstat						&&	\
	./autogen.sh						&&	\
	./configure						&&	\
	make							&&	\
	make install						&&	\
	make clean

## Nagios 4.3.1 has leftover debug code which spams syslog every 15 seconds
## Its fixed in 4.3.2 and the patch can be removed then

	
RUN	cd /tmp							&&	\
	git clone https://github.com/NagiosEnterprises/nagioscore.git -b nagios-4.3.2		&&	\
	cd nagioscore						&&	\
	./configure							\
		--prefix=${NAGIOS_HOME}					\
		--exec-prefix=${NAGIOS_HOME}				\
		--enable-event-broker					\
		--with-command-user=${NAGIOS_CMDUSER}			\
		--with-command-group=${NAGIOS_CMDGROUP}			\
		--with-nagios-user=${NAGIOS_USER}			\
		--with-nagios-group=${NAGIOS_GROUP}		&&	\
	make all						&&	\
	make install						&&	\
	make install-config					&&	\
	make install-commandmode				&&	\
	make install-webconf					&&	\
	make clean

RUN	cd /tmp							&&	\
	git clone https://github.com/nagios-plugins/nagios-plugins.git -b release-2.2.1		&&	\
	cd nagios-plugins					&&	\
	./tools/setup						&&	\
	./configure							\
		--prefix=${NAGIOS_HOME}				&&	\
	make							&&	\
	make install						&&	\
	make clean	&&	\
	mkdir -p /usr/lib/nagios/plugins	&&	\
	ln -sf /opt/nagios/libexec/utils.pm /usr/lib/nagios/plugins

RUN	cd /tmp							&&	\
	git clone https://github.com/NagiosEnterprises/nrpe.git	-b nrpe-3.1.1	&&	\
	cd nrpe							&&	\
	./configure							\
		--with-ssl=/usr/bin/openssl				\
		--with-ssl-lib=/usr/lib/x86_64-linux-gnu	&&	\
	make check_nrpe						&&	\
	cp src/check_nrpe ${NAGIOS_HOME}/libexec/		&&	\
	make clean

RUN	cd /tmp											&&	\
	git clone https://git.code.sf.net/p/nagiosgraph/git nagiosgraph				&&	\
	cd nagiosgraph										&&	\
	./install.pl --install										\
		--prefix /opt/nagiosgraph								\
		--nagios-user ${NAGIOS_USER}								\
		--www-user ${NAGIOS_USER}								\
		--nagios-perfdata-file ${NAGIOS_HOME}/var/perfdata.log					\
		--nagios-cgi-url /cgi-bin							&&	\
	cp share/nagiosgraph.ssi ${NAGIOS_HOME}/share/ssi/common-header.ssi

RUN cd /opt &&		\
	git clone https://github.com/willixix/naglio-plugins.git	WL-Nagios-Plugins	&&	\
	git clone https://github.com/JasonRivers/nagios-plugins.git	JR-Nagios-Plugins	&&	\
	git clone https://github.com/justintime/nagios-plugins.git      JE-Nagios-Plugins       &&      \
	chmod +x /opt/WL-Nagios-Plugins/check*                                                  &&      \
	chmod +x /opt/JE-Nagios-Plugins/check_mem/check_mem.pl                                  &&      \
	cp /opt/JE-Nagios-Plugins/check_mem/check_mem.pl /opt/nagios/libexec/                   &&      \
	cp /opt/nagios/libexec/utils.sh /opt/JR-Nagios-Plugins/


RUN	sed -i.bak 's/.*\=www\-data//g' /etc/apache2/envvars
RUN	export DOC_ROOT="DocumentRoot $(echo $NAGIOS_HOME/share)"					&&	\
	sed -i "s,DocumentRoot.*,$DOC_ROOT," /etc/apache2/sites-enabled/000-default.conf		&&	\
	sed -i "s,</VirtualHost>,<IfDefine ENABLE_USR_LIB_CGI_BIN>\nScriptAlias /cgi-bin/ /opt/nagios/sbin/\n</IfDefine>\n</VirtualHost>," /etc/apache2/sites-enabled/000-default.conf	&&	\
	ln -s /etc/apache2/mods-available/cgi.load /etc/apache2/mods-enabled/cgi.load

RUN	mkdir -p -m 0755 /usr/share/snmp/mibs							&&	\
	mkdir -p         ${NAGIOS_HOME}/etc/conf.d						&&	\
	mkdir -p         ${NAGIOS_HOME}/etc/monitor						&&	\
	mkdir -p -m 700  ${NAGIOS_HOME}/.ssh							&&	\
	chown ${NAGIOS_USER}:${NAGIOS_GROUP} ${NAGIOS_HOME}/.ssh				&&	\
	touch /usr/share/snmp/mibs/.foo								&&	\
	ln -s /usr/share/snmp/mibs ${NAGIOS_HOME}/libexec/mibs					&&	\
	ln -s ${NAGIOS_HOME}/bin/nagios /usr/local/bin/nagios					&&	\
	download-mibs && echo "mibs +ALL" > /etc/snmp/snmp.conf

RUN	sed -i 's,/bin/mail,/usr/bin/mail,' /opt/nagios/etc/objects/commands.cfg		&&	\
	sed -i 's,/usr/usr,/usr,'           /opt/nagios/etc/objects/commands.cfg

RUN	cp /etc/services /var/spool/postfix/etc/	&&\
	echo "smtp_address_preference = ipv4" >> /etc/postfix/main.cf

RUN	rm -rf /etc/rsyslog.d /etc/rsyslog.conf

RUN	rm -rf /etc/sv/getty-5

ADD nagios/nagios.cfg /opt/nagios/etc/nagios.cfg
ADD nagios/cgi.cfg /opt/nagios/etc/cgi.cfg
ADD nagios/templates.cfg /opt/nagios/etc/objects/templates.cfg
ADD nagios/commands.cfg /opt/nagios/etc/objects/commands.cfg
ADD nagios/localhost.cfg /opt/nagios/etc/objects/localhost.cfg

ADD rsyslog/rsyslog.conf /etc/rsyslog.conf

RUN echo "use_timezone=${NAGIOS_TIMEZONE}" >> /opt/nagios/etc/nagios.cfg

# Copy example config in-case the user has started with empty var or etc

RUN mkdir -p /orig/var && mkdir -p /orig/etc				&&	\
	cp -Rp /opt/nagios/var/* /orig/var/					&&	\
	cp -Rp /opt/nagios/etc/* /orig/etc/

RUN a2enmod session					&&\
    a2enmod session_cookie				&&\
    a2enmod session_crypto				&&\
    a2enmod auth_form					&&\
    a2enmod request

ADD nagios.init /etc/sv/nagios/run
ADD apache.init /etc/sv/apache/run
ADD postfix.init /etc/sv/postfix/run
ADD rsyslog.init /etc/sv/rsyslog/run
ADD start.sh /usr/local/bin/start_nagios
RUN chmod +x /usr/local/bin/start_nagios

# enable all runit services
RUN ln -s /etc/sv/* /etc/service

ENV APACHE_LOCK_DIR /var/run
ENV APACHE_LOG_DIR /var/log/apache2

#Set ServerName and timezone for Apache
RUN echo "ServerName ${NAGIOS_FQDN}" > /etc/apache2/conf-available/servername.conf	&& \
    echo "PassEnv TZ" > /etc/apache2/conf-available/timezone.conf			&& \
    ln -s /etc/apache2/conf-available/servername.conf /etc/apache2/conf-enabled/servername.conf	&& \
    ln -s /etc/apache2/conf-available/timezone.conf /etc/apache2/conf-enabled/timezone.conf

EXPOSE 80

VOLUME "/opt/nagios/var" "/opt/nagios/etc" "/opt/nagios/libexec" "/var/log/apache2" "/usr/share/snmp/mibs" "/opt/Custom-Nagios-Plugins"

CMD [ "/usr/local/bin/start_nagios" ]
