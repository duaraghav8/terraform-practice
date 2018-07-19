# terraform-practice
Just practicing Terraform. See file `target` to know what is being created. All variables have been `.gitignore`d so you'll have to inject your own variable values.

In order to be able to ssh into the machine, we provide TF with an ssh public key to associate with that machine (this is optional in TF). Here, `ci_server_public_key` is to be provided by the user. Generate a key pair using `ssh-keygen -t rsa -b 4096`. Provide TF with the public key. Keep the private key, well, private.

Focus is only on learning concepts, not paying attention to modularity at the moment.
