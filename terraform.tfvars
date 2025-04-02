aws_region             = "ap-south-1"                                                       # AWS region where Seafile will be set up
instance_type          = "t3.micro"                                                         # EC2 instance type
key_name               = "seafile"                                                          # Name of an existing SSH key to access the EC2 instance
vpc_cidr               = "172.32.0.0/28"                                                    # CIDR block for the new Seafile VPC
sg_cidr                = ["27.68.86.46/32"]                                                 # CIDR blocks for the Security Group (IP ranges where Seafile and the EC2 instance will be accessed from)
bucket_name            = "not-your-bucket-tbh"                                              # Name for the new S3 bucket serving as data store
mysql_root_password    = "my_very_secure_password_1"                                        # Password for the MySQL root user
mysql_seafile_password = "my_very_secure_password_2"                                        # Password for the MySQL seafile user
download_url           = "https://download.seadrive.org/seafile-server_11.0.5_x86-64.tar.gz"# URL of the Seafile server package
seahub_email           = "my_email@address.com"                                             # Email address for the Seahub admin user
seahub_password        = "my_very_secure_password_3"                                        # Password for the Seahub admin user
hosted_zone            = "Z1AB1Z2CDE3FG"                                                    # Hosted zone ID for the DNS record in Route53
dns_record             = "1.2.3.4"                                                          # DNS record (type A) for the webserver, to be created in Route53


