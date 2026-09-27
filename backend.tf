terraform {
  required_version = "1.16.4"

  cloud {
    
    organization = "DigitalTech"

    workspaces {
      name = "gitaction_aws_container-tfc"
    }
  }
}