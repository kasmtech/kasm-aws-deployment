output "bucket_arn" {
  description = "S3 Persistent Profile bucket arn"
  value       = aws_s3_bucket.s3_bucket.arn
}

