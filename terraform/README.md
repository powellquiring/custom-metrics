# Creating a vpc, instance, floating ip

See installation instructions for terraform and the ibmcloud cli in [Getting started with solution tutorials](https://cloud.ibm.com/docs/solution-tutorials?topic=solution-tutorials-tutorials)

```
cp template.local.env local.env
vi local.env; # use any editor, changes required should be self explanitory
source local.env
terraform init
terraform apply
```

The last few lines of the `terraform apply` output should look like this:

```
Apply complete! Resources: x added, y changed, z destroyed.

Outputs:

hostname = "basename"
ip = "1.2.3.4"
ssh = "ssh root@1.2.3.4"
```
