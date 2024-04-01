provider "aws" {
  region = "us-east-2"
  default_tags {
    tags = {
      team    = "science"
      project = "openscpca"
      purpose = "openscpca-nf-batch"
      config  = "https://github.com/AlexsLemonade/OpenScPCA-nf/terraform"
    }
  }
}
