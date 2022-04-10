#!/bin/bash

hostnamectl set-hostname kube-install.learn.entigo.io
echo 'preserve_hostname: true' >> /etc/cloud/cloud.cfg

PATH=$PATH:/usr/local/bin
export PATH

echo "
PATH=$PATH:/usr/local/bin
export PATH
" >> /root/.bash_profile

echo "
PATH=$PATH:/usr/local/bin
export PATH
" >> /etc/profile.d/sh.local

