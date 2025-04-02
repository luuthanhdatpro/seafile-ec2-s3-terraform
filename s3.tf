# S3 bucket to be used as Seafile data store
resource "aws_s3_bucket" "datastore" {
  bucket = var.bucket_name
  # Access control is managed via bucket policy or IAM policies

  # Allow deletion of non-empty bucket
  force_destroy = true

  tags = {
    Name = local.project_name
  }

}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption_rule" {
  bucket = aws_s3_bucket.datastore.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.kms_key.key_id
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_kms_key" "kms_key" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket_public_access_block" "s3_access_block" {
  bucket = aws_s3_bucket.datastore.id

  # Block all public access to the bucket
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

