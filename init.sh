#!/usr/bin/sh

run_ssh_keygen(){
        rm -rf $HOME/.ssh/id_rsa.pub
        /usr/bin/expect<<EOF
        set timeout 10
        spawn ssh-keygen -t rsa -b 2048
        expect {
               "Enter file in" {send "\n"; exp_continue}
               "Overwrite (y/n)" {send "y\n"; exp_continue}
               "Enter passphrase" {send "\n"; exp_continue}
               "passphrase again" {send "\n"; exp_continue}
           }
EOF
}

send_ssh_key(){
        pwd=vagrant
        /usr/bin/expect<<EOF
        set timeout 30
        spawn ssh-copy-id vagrant@$1
        expect {
              "connecting (yes/no)?" {send "yes\n"; exp_continue}
              "password:" {send "$pwd\n"; exp_continue}
        }
EOF
}

sudo cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sudo systemctl restart sshd

if [ "$HOSTNAME" = "ansible-controller" ]; then
        sudo yum install -y epel-release git vim gcc expect glibc-static telnet ansible
        sudo sh -c "echo 192.168.56.6 ansible-node1 >> /etc/hosts"
        sudo sh -c "echo 192.168.56.7 ansible-node2 >> /etc/hosts"
        sudo sh -c "echo 192.168.56.4 ansible-node3 >> /etc/hosts"
        run_ssh_keygen
        if [ -f $HOME/.ssh/id_rsa.pub ]; then
            for suffix in 4 6 7
            do
                send_ssh_key "192.168.56.$suffix"
            done
        fi
fi
