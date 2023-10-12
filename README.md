# AWS ELB + Access Logs

Short example for Application Load Balancer sending access logs do S3.

Server-side encryption for this integration only supports Amazon S3-managed keys (SSE-S3).

Reference [from the docs][1]:

> The only server-side encryption option that's supported is Amazon S3-managed keys (SSE-S3). For more information, see Amazon S3-managed encryption keys (SSE-S3).

Create the temporary key pair:

```sh
mkdir -p keys
ssh-keygen -f keys/temp_key
```

Copy the sample `.auto.tfvars` file:

```sh
cp samples/sample.tfvars .auto.tfvars
```

Start the environment:

```sh
terraform init
terraform apply -auto-approve
```

ELB will confirm that the configuration worked by creating the file `ELBAccessLogTestFile`:

```
https://<bucket>.s3.<region>.amazonaws.com/<prefix>/AWSLogs/<account>/ELBAccessLogTestFile
```

Once traffic starts coming in to ELB the access logs will be generated in the S3. You can use Athena to query the results.


[1]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html#access-log-create-bucket
