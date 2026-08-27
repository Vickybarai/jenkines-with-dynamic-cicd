# Copy to terraform.tfvars. Do not commit terraform.tfvars.

aws_region  = "us-east-1"
environment = "dev"
application = "cdec-alpha-cbzpb"

acm_certificate_arn = ""

# Use a domain you own — example.com is reserved by AWS and will fail
dns_zone_name   = ""
dns_record_name = ""
