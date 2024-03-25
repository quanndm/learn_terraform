variable "vpc_cidr_block" {
    description = "cidr_block of VPC - ex:10.0.0.0/16 "
}

variable "public_subnet_cidr_block" {
    description = "cidr_block of public subnet - ex: 10.0.1.0/24"
}

variable "public_subnet_availibility_zone" {
    description = "availibility_zone of public subnet - ex: ap-southeast-1a"
}


variable "instance_type_server_instance" {
    description = "instance_type of server instance - ex: t2.micro"
}