# Data From Existing Infrastructure

data "terraform_remote_state" "existing-hub" {
  backend = "remote"

  config = {
    organization = "jcroth"

    workspaces = {
      name = "cs-aks-hub"
    }
  }
}

# Variables for Spoke/LZ 

variable "tags" {
  type = map(string)

  default = {
    project = "spoke-lz"
  }
}

variable "lz_prefix" {
  default = "escs-lz01"
}














