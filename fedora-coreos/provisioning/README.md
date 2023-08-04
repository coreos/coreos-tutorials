
If this is the first time being run then:

```
terraform init
```

Set the following environment variables to set the labuser passwords for the instance and also the SSH public key to use for logging in as the `core` user on the instance, which has `sudo` access.

```
export TF_VAR_core_user_ssh_pubkey_string=<ssh-rsa AAAA..>
export TF_VAR_student_password_hash=<password>
```

```
terraform apply
```

Will bring up the instance and show you the IP to contact.

To bring down just the instance:

```
terraform destroy -target aws_instance.fcos-lab-instance
```

To bring down all resources:

```
terraform destroy
```
