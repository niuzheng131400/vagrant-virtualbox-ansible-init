## ansible 环境准备

### 我们使用 `Vagrant`+ `VirtualBox` 创建虚拟机

#### 这里对于`Vagrant`以及`VirtualBox`的安装使用就不再过多介绍，有需要小伙伴请移步到以下文章参考了解学习。
- [vagrantfile创建多个Host](https://niuzheng.net/archives/2729/) 
- [Mac上下载安装Vagrant、配置打包属于自己的开发环境（使用Homestead后续也会更新出来）](https://niuzheng.net/archives/665/)
- [kong接入网关](https://niuzheng.net/archives/2411/)的`准备工作`部分  (Vagrant和VirtualBox `版本兼容问题`在这篇有提及到)

### 目录介绍
- ansible-code[1-4]为宿主机与虚拟机之间的共享目录
```bash
├─ansible-code1   # hostname:ansible-controller  ip:192.168.56.5  box: CentOS
├─ansible-code2   # hostname:ansible-node1  ip:192.168.56.6  box: CentOS
├─ansible-code3   # hostname:ansible-node2  ip:192.168.56.7  box: CentOS
└─ansible-code4   # hostname:ansible-node3  ip:192.168.56.4  box: Ubuntu
└─box             # 放box镜像
└─init.sh
└─vagrantfile
```

### 提前下载centos.box 和 ubuntu.box 到本地的box目录
```
vagrant box add centos ./box/centos.box 
vagrant box add ubuntu ./box/ubuntu.box 
vagrant box list
centos      (virtualbox, 0)
ubuntu      (virtualbox, 0)
```

### init.sh 
- 设置时区
- 设置可以密码登陆
- 在ansible-controller机器上设置节点host
- 安装一些软件
- 在ansible-controller使用`expect`免交互式生成并发送ssh_key到节点服务器

```bash
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
```
### vagrantfile
```bash
hosts = [
    {
         :box => 'centos',
         :define => 'ansible-controller',
         :hostname =>'ansible-controller',
         :private_network => '192.168.56.5',
         :vb_name => 'ansible-controller',
         :synced_folder =>{
          :local => 'E:/code/test/vm/Ansible/ansible-code1',
          :virtual => '/www/ansible-code/test'
         }
    },
    {
	 :box => 'centos',
         :define => 'ansible-node1',
         :hostname =>'ansible-node1',
         :private_network => '192.168.56.6',
         :vb_name => 'ansible-node1',
         :synced_folder =>{
            :local => 'E:/code/test/vm/Ansible/ansible-code2',
            :virtual => '/www/ansible-code/test'
          }
         
    },
    {
	 :box => 'centos',
         :define => 'ansible-node2',
         :hostname =>'ansible-node2',
         :private_network => '192.168.56.7',
         :vb_name => 'ansible-node2',
         :synced_folder =>{
            :local => 'E:/code/test/vm/Ansible/ansible-code3',
            :virtual => '/www/ansible-code/test'
         }
    },
	{
	     :box => 'ubuntu',
	     :define => 'ansible-node3',
	     :hostname =>'ansible-node3',
	     :private_network => '192.168.56.4',
	     :vb_name => 'ansible-node3',
	     :synced_folder =>{
	        :local => 'E:/code/test/vm/Ansible/ansible-code4',
	        :virtual => '/www/ansible-code/test'
	     }
	}
]

Vagrant.configure("2") do |config|
    hosts.each do |item|
         config.vm.define item[:define] do |host|
	    host.vm.box = item[:box]
            host.vm.hostname = item[:hostname]
            host.vm.network "private_network", ip: item[:private_network]
            if item[:synced_folder]
               host.vm.synced_folder item[:synced_folder][:local], item[:synced_folder][:virtual],mount_options: ["dmode=775","fmode=664"]
            end
            host.vm.provider "virtualbox" do |vb|
                vb.memory = "1024"
                vb.cpus = "1"
                vb.name = item[:vb_name]
                vb.customize [ "modifyvm", :id, "--uartmode1", "disconnected" ]
            end
         end
    end
	config.vm.provision "shell", privileged: false, path: "./init.sh"
end
```
### [ansible 环境准备博客地址](https://niuzheng.net/archives/2815/)