terraform {
  backend "s3" {
    bucket = "terraform"
    key    = "${var.deploy_id}.tfstate"
    # endpoint                    = "https://zhw-a.s3.cloud.switch.ch"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    # Uncomment and set if using server-side encryption
    # encrypt        = true
    # kms_key_id     = "YOUR_KMS_KEY_ID"
  }

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.2.0"
    }
  }
}
