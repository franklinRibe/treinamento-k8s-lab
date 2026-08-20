Put this config in your ssh config in ~/.ssh/config

and after access with this command:

```
 ssh ipros-prod
```

```bash
Host bastion
  Hostname 52.90.211.81
  User ec2-user
  IdentityFile ~/.ssh/key.pem

Host instance-prod
  Hostname 10.0.2.75
  Port 22
  User centos
  ForwardAgent yes
  ProxyCommand ssh -W %h:%p bastion 2> /dev/null
  IdentityFile ~/.ssh/key.pem

Host instance-stg
  Hostname 10.0.2.80
  Port 22
  User centos
  ForwardAgent yes
  ProxyCommand ssh -W %h:%p bastion 2> /dev/null
  IdentityFile ~/.ssh/key.pem

########