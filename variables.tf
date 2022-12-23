variable "region_name" {

    default = "us-east-1"
  
}

variable "vpc_cidr" {
    default = "10.0.0.0/16"
 }

variable "sub1_cidr" {
    default = "10.0.0.0/24"
  }

variable "sub2_cidr" {
    default = "10.0.1.0/24"
  }

variable "sub3_cidr" {
    default = "10.0.2.0/24"
  }

  variable "sub4_cidr" {
    default = "10.0.3.0/24"
  }

  variable "IGW" {
    default = "0.0.0.0/0"
    
  }

  variable "ngw_cidr" {
    default = "0.0.0.0/0"
    
  }

  variable "ami_id" {
    default = "ami-0b5eea76982371e91"
    }

    variable "instance_type" {
     default = "t2.micro"
      }

      variable "key_name" {
      default = "citibank-ec2-key"
        
      }

      variable "source_instance_id" {

        default = "i-0469cdb021d1fbf4c"
        
      }

//hardcoding values for sg
variable "ingress_rules" {
default = {
  "my ingress rule" = {
    description = "For HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  "my other ingress rule" = {
    description = "For SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
}

variable "db_name" {
  default = "mydb"
}

variable "engine_name" {
  default = "mysql"
}

variable "instance_class" {
  default = "db.t2.micro"
}

variable "engine_version" {
    default = "5.7"
  }

variable "username" {
default = "sqlusername"
  }