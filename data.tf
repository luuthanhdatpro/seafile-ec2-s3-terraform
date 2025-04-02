# Get the most recent Amazon Linux 2 AMI
data "aws_ami" "ubuntu_24" {
  most_recent         = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20250305"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  owners = ["099720109477"] # Ubuntu's official AWS account ID

  tags = {
    Name = "Ubuntu-24-AMI"
  }
}


# Script for copying certificate, web server config and service files from localhost to the Seafile server
data "template_file" "file_copy" {
  template = <<EOF
        #!/bin/bash
        echo ${base64encode(file("conf/seafile.conf"))} | base64 --decode > /etc/nginx/sites-available/seafile.conf
        echo ${base64encode(file("conf/seafile.service"))} | base64 --decode > /usr/lib/systemd/system/seafile.service
        echo ${base64encode(file("conf/seahub.service"))} | base64 --decode > /usr/lib/systemd/system/seahub.service
        EOF
}

# User data including all commands for Seafile setup
data "template_file" "user_data" {
	vars = {
		download_url= "${var.download_url}"
		bucket_name= "${var.bucket_name}"
		mysql_seafile_password= "${var.mysql_seafile_password}"
		seahub_email= "${var.seahub_email}"
		seahub_password= "${var.seahub_password}"
		dns_record= "${var.dns_record}"
		aws_iam_role= "${aws_iam_role.instance_role.id}"
		mysql_root_password= "${var.mysql_root_password}"
		template_file= "${data.template_file.file_copy.rendered}"
		s3fs_endpoint_url= "${local.s3fs_endpoint_url}"
	}
  template = "${file("conf/user_data.tpl")}"
}
