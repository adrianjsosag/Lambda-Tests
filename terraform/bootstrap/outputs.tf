output "state_bucket_name" {
  description = "Usar este valor como 'bucket' en environments/*/backend.tf"
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN del bucket, útil para políticas IAM de acceso al estado"
  value       = aws_s3_bucket.state.arn
}
