variable "aws_region" {
  type        = string
  description = "Região da AWS"
  default     = "us-east-1"
}

variable "vpc_name" {
  type        = string
  description = "Nome da VPC"
  default     = "PezaoSound-vpc"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR da VPC"
  default     = "10.0.0.0/24"
}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR da subrede pública"
  default     = "10.0.0.0/27"
}

variable "public_subnet_name" {
  type        = string
  description = "Nome da subrede pública"
  default     = "public_subnet"
}

variable "public_subnet_availability_zone" {
  type        = string
  description = "AZ da subrede pública"
  default     = "a"
}

variable "app_subnet_name" {
  type        = string
  description = "Nome da subrede de aplicação"
  default     = "app_subnet"
}

variable "app_subnet_1_cidr" {
  type        = string
  description = "CIDR da subrede 1 de aplicação"
  default     = "10.0.0.32/27"
}

variable "app_subnet_2_cidr" {
  type        = string
  description = "CIDR da subrede 2 de aplicação"
  default     = "10.0.0.64/27"
}

variable "app_web_subnet_1_availability_zone" {
  type        = string
  description = "AZ da subrede 1 de aplicação e WEB"
  default     = "a"
}

variable "app_web_subnet_2_availability_zone" {
  type        = string
  description = "AZ da subrede 2 de aplicação e WEB"
  default     = "b"
}

variable "db_subnet_name" {
  type        = string
  description = "Nome da subrede de banco de dados"
  default     = "db_subnet"
}

variable "db_subnet_cidr" {
  type        = string
  description = "CIDR da subrede de banco de dados"
  default     = "10.0.0.96/27"
}

variable "db_subnet_availability_zone" {
  type        = string
  description = "AZ da subrede de banco de dados"
  default     = "a"
}

variable "web_subnet_name" {
  type        = string
  description = "Nome da subrede WEB"
  default     = "web_subnet"
}

variable "web_subnet_1_cidr" {
  type        = string
  description = "CIDR da subrede 1 WEB"
  default     = "10.0.0.128/27"
}

variable "web_subnet_2_cidr" {
  type        = string
  description = "CIDR da subrede 2 web"
  default     = "10.0.0.160/27"
}