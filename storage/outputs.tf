output "bucketname" {
    value = "${aws_s3_bucket.bucket_res.id}"
}