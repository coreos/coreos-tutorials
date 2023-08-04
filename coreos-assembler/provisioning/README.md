
If this is the first time being run then:

```
terraform init
```

Update the password in `main.tf` and the SSH pubkey in `cosa-lab-tutorial.bu`:

```
terraform apply
```

Will bring up the instance and show you the IP to contact.

To bring down just the instance:

```
terraform destroy -target aws_instance.cosa-lab-instance
```

To bring down all resources:

```
terraform destroy
```
