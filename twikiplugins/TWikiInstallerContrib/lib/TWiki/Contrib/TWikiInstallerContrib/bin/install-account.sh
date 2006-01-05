#! /bin/sh

ACCOUNT=$1

if ! [ -d /home/$ACCOUNT ];
then
	echo Creating and initialising '$ACCOUNT' user account
	sudo adduser --disabled-password --gecos $ACCOUNT $ACCOUNT
	sudo usermod -G www-data $ACCOUNT;
fi

if ! [ -d /home/$ACCOUNT/.ssh ];
then
	echo Installing SSH keys;
	sudo cp -r /home/twikibuilder/.ssh /home/$ACCOUNT
	sudo chown -R $ACCOUNT.$ACCOUNT /home/$ACCOUNT/.ssh
fi

if [ -d /home/$ACCOUNT/public_html/cgi-bin ]
then
	echo Removing previous TWiki installation
	sudo rm -rf /home/$ACCOUNT/public_html
fi

echo Creating web directory structure
sudo -u $ACCOUNT mkdir -p /home/$ACCOUNT/public_html/cgi-bin
sudo -u $ACCOUNT chmod g+w /home/$ACCOUNT/public_html/cgi-bin
sudo chgrp -R www-data /home/$ACCOUNT/public_html;

if ! [ -d /home/$ACCOUNT/public_html/cgi-bin/lib/CPAN ]
then
	echo "Installing dirty little secret CPAN library (for the moment...)"
	sudo -u $ACCOUNT cp -r lib /home/$ACCOUNT/public_html/cgi-bin;
fi

echo Installing...
time bin/install-twiki.pl \
	--dir=$ACCOUNT@localhost:~/public_html/cgi-bin \
	--url=http://localhost/~$ACCOUNT/cgi-bin/twiki-install.cgi \
	$EXTENSIONS \
