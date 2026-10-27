terraform {
  backend "s3" {
    # Sustituir por el output 'state_bucket_name' de terraform/bootstrap
    bucket       = "lambda-tests-tfstate-<ACCOUNT_ID>"
    key          = "dev/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
