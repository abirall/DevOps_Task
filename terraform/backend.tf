
terraform {
  backend "s3" {
    key          = "python-app/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
