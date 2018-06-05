# storage
resource "random_id" "bucket_id" {
    byte_length = 2
}

resource "aws_s3_bucket" "bucket_res" {
    bucket = "${var.project_name}-${random_id.bucket_id.dec}"
    acl = "private"
    force_destroy = true
    tags {
        name = "terraform_bucket"
    }
    
}