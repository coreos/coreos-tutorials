
If this is the first time being run then:

```
terraform init
```

Set the following environment variables to set the labuser passwords for the instance and also the SSH public key to use for logging in as the `core` user on the instance, which has `sudo` access.

```
export TF_VAR_core_user_ssh_pubkey_string=<ssh-rsa AAAA..>
export TF_VAR_student_password_hash=<password>
```

Configure AWS credentials in your environment (env variables or profile files in expected locations). For example:

```
 export AWS_REGION=us-east-1
 export AWS_ACCESS_KEY_ID=...
 export AWS_SECRET_ACCESS_KEY=...
```

To bring up an instance and output the IP for you to SSH to:

```
terraform apply
```

To bring down just the instance:

```
terraform destroy -target aws_instance.cosa-lab-instance
```

To bring down all resources:

```
terraform destroy
```
