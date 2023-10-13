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

## Querying with Athena

Once access are on an S3 bucket, it is time to analyze it. This next section will follow the documentation for [Querying Application Load Balancer logs][2].

We'll use Glue + Athena to achieve that.

It is worth remembering that Athena can query several data sources:

<img src=".assets/athena-datasources.png" width=700 />

To query the ELB access logs available on S3, a database is required, and the Terraform scripts will create one.

It is possible to do it manually by creating a table, or by using Glue data crawler.

<img src=".assets/athena-glue.png" />

Create a table directly from Athena. There are two options:

- No partitions
- With partitions

As per documentation for PARTITIONED table:

> Because ALB logs have a known structure whose partition scheme you can specify in advance, you can reduce query runtime and automate partition management by using the Athena partition projection feature. Partition projection automatically adds new partitions as new data is added. This removes the need for you to manually add partitions by using `ALTER TABLE ADD PARTITION`.

Use the local file [`alb_logs.sql`](alb_logs.sql) as a reference, but try getting it fresh from the documentation. It is necessary to replace the S3 data source references in the Athena SQL command. The value is provided as an output by Terraform.

```
s3://your-alb-logs-directory/AWSLogs/<ACCOUNT-ID>/elasticloadbalancing/<REGION>/
```

Terraform will also prepare an Athena Workgroup with a dedicated S3 output.


---

### Clean-up

```sh
terraform destroy -auto-approve
```

[1]: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html#access-log-create-bucket
[2]: https://docs.aws.amazon.com/athena/latest/ug/application-load-balancer-logs.html
