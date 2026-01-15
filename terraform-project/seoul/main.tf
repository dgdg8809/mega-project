terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
provider "aws" {
  region = local.vars.region
}



locals {
  vars = yamldecode(file("${path.module}/variables.yml"))

  # DVWA 전용 user_data
  dvwa_user_data = templatefile("${path.module}/user_data_dvwa.sh.tftpl", {
    # --- EFS ---
    efs_id = module.efs.file_system_id

    # --- RDS ---
    rds_port     = module.rds.port
    rds_master   = local.vars.rds.master_username
    rds_password = local.vars.rds.master_password

    # --- DVWA ---
    dvwa_db   = local.vars.apps.dvwa.db_name
    dvwa_user = local.vars.apps.dvwa.db_user
    dvwa_pass = local.vars.apps.dvwa.db_password

    # --- DB DNS (Route53) ---
    db_host = local.vars.route53.db_record_name
  })

  # GNUBoard 전용 user_data (웹 설치 방식)
  gnuboard_user_data = templatefile("${path.module}/user_data_gnuboard.sh.tftpl", {
    DB_HOST       = "db.iac.it-edu.org"
    DB_PORT       = module.rds.port
    RDS_MASTER    = local.vars.rds.master_username
    RDS_MASTER_PW = local.vars.rds.master_password

    G5_DB   = local.vars.apps.gnuboard.db_name
    G5_USER = local.vars.apps.gnuboard.db_user
    G5_PASS = local.vars.apps.gnuboard.db_password

    
    BASE_URL      = "http://gnuboard.iac.it-edu.org"
    COOKIE_DOMAIN = ""
    G5_URL        = "http://gnuboard.iac.it-edu.org"

    ADMIN_ID    = "webmaster"
    ADMIN_PW    = "Password"
    ADMIN_EMAIL = "webmaster@iac.it-edu.org"
  })


  wordpress_user_data = templatefile("${path.module}/user_data_wordpress.sh.tftpl", {
    # --- RDS ---
    DB_HOST       = "db.iac.it-edu.org"
    DB_PORT       = module.rds.port
    RDS_MASTER    = local.vars.rds.master_username
    RDS_MASTER_PW = local.vars.rds.master_password

    # --- WP DB ---
    WP_DB   = local.vars.apps.wordpress.db_name
    WP_USER = local.vars.apps.wordpress.db_user
    WP_PASS = local.vars.apps.wordpress.db_password

    # --- WP Admin ---
    WP_ADMIN_USER  = local.vars.apps.wordpress.admin_user
    WP_ADMIN_PASS  = local.vars.apps.wordpress.admin_password
    WP_ADMIN_EMAIL = local.vars.apps.wordpress.admin_email

    # --- WP Site ---
    WP_SITE_TITLE = local.vars.apps.wordpress.site_title
    WP_URL        = "http://wordpress.iac.it-edu.org"
    COOKIE_DOMAIN = "iac.it-edu.org"
  })

}






module "vpc" {
  source               = "../modules/vpc"
  cidr_block           = local.vars.cidr_block
  region_name          = local.vars.region_name
  az_count             = local.vars.az_count
  subnet_bits          = local.vars.subnet_bits
  public_subnet_count  = local.vars.public_subnet_count
  private_subnet_count = local.vars.private_subnet_count
  # enable_nat_gateway   = true

}

module "security_group" {
  source         = "../modules/security-group"
  vpc_id         = module.vpc.vpc_id
  region         = { name = local.vars.region_name }
  security_group = local.vars.security_groups
}

module "keypair" {
  source      = "../modules/keypair"
  region_name = local.vars.region_name
  key_info    = local.vars.key_info
}

module "rds" {
  source = "../modules/rds"

  identifier = "${local.vars.region_name}-rds"

  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = module.security_group.sg_ids["rds"]

  engine         = local.vars.rds.engine
  instance_class = local.vars.rds.instance_class

  db_name  = local.vars.rds.initial_db_name
  username = local.vars.rds.master_username
  password = local.vars.rds.master_password
}


module "efs" {
  source = "../modules/efs"

  name              = "${local.vars.region_name}-efs"
  subnet_ids        = module.vpc.private_subnet_ids
  security_group_id = module.security_group.sg_ids["efs"]
}




module "alb_dvwa" {
  source = "../modules/alb"

  name              = "${local.vars.region_name}-dvwa-alb"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.security_group.sg_ids["web"]

  health_check_path = "/healthz.html"
}

module "alb_gnuboard" {
  source = "../modules/alb"

  name              = "${local.vars.region_name}-gnuboard-alb"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.security_group.sg_ids["web"]

  health_check_path = "/healthz.html"
}

module "alb_wordpress" {
  source = "../modules/alb"

  name              = "${local.vars.region_name}-wordpress-alb"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.security_group.sg_ids["web"]

  health_check_path = "/healthz.html"
}

# ----------------------------
# WAF (서비스별 분리)
# ----------------------------

module "waf_wordpress" {
  source         = "../modules/waf"
  name           = "seoul-waf-wordpress"
  description    = "WAF for WordPress ALB"
  scope          = "REGIONAL"
  default_action = "allow"

  alb_arn       = module.alb_wordpress.alb_arn
  metric_name   = "waf-wordpress"
  



  # 간단 버전(대표 3개)
  managed_rule_groups = [
    {
      name            = "AWSManagedRulesCommonRuleSet"
      vendor_name     = "AWS"
      priority        = 10
      override_action = "none"
    },
    {
      name            = "AWSManagedRulesSQLiRuleSet"
      vendor_name     = "AWS"
      priority        = 20
      override_action = "none"
    },
    {
      name            = "AWSManagedRulesWordPressRuleSet"
      vendor_name     = "AWS"
      priority        = 30
      override_action = "none"
    }
  ]

  
  rate_limit = 2000

 
  custom_rules = [
    {
      name     = "block-command-injection"
      priority = 100
      action   = "block"
      statement = {
        patterns = [
          "cat",
          "ls",
          "whoami",
          "id",
          "uname",
          "pwd",
          "ps ",
          "etc/passwd",
          "; ",
          "|",
          "&",
          "$(",
          "`",
          "system(",
          "exec(",
          "passthru(",
          "shell_exec(",
          "cmd.exe",
          "powershell",
          "windows\\",
        ]
        field_to_match = "all_query_arguments"
      }
    },
    {
      name     = "block-wordpress-sensitive-endpoints"
      priority = 101
      action   = "block"
      statement = {
        patterns = [
          "/wp-admin/admin-ajax.php",
          "wp-config.php",
          "/wp-content/themes/",
          "/wp-json/wp/v2/users",
        ]
        field_to_match = "uri"
      }
    }
  ]
}

module "waf_gnuboard" {
  source         = "../modules/waf"
  name           = "seoul-waf-gnuboard"
  description    = "WAF for GNUBoard ALB"
  scope          = "REGIONAL"
  default_action = "allow"

  alb_arn       = module.alb_gnuboard.alb_arn
  metric_name   = "waf-gnuboard"
  



  managed_rule_groups = [
    {
      name            = "AWSManagedRulesCommonRuleSet"
      vendor_name     = "AWS"
      priority        = 10
      override_action = "none"
    },
    {
      name            = "AWSManagedRulesSQLiRuleSet"
      vendor_name     = "AWS"
      priority        = 20
      override_action = "none"
    }
  ]

  rate_limit = 2000

  # 커스텀 규칙: Command Injection, LDAP Injection 차단
  custom_rules = [
    {
      name     = "block-command-injection"
      priority = 100
      action   = "block"
      statement = {
        patterns = [
          "; ls",
          ";ls",
          "; rm",
          ";rm",
          "| whoami",
          "|whoami",
          "| ls",
          "|ls",
          "&& cat",
          "&&cat",
          "&& rm",
          "&&rm",
          "/etc/passwd",
          "| cat",
          "|cat",
          "$(whoami)",
          "`whoami`",
          "$(cat",
          "`cat",
          "; cat",
          ";cat",
          "|cat",
          "& cat",
          "|whoami",
          "| grep",
          "|head",
          "|tail",
          "system(",
          "exec(",
          "passthru(",
          "shell_exec(",
          "&&ls",
          "||cat",
          "; whoami",
          ";whoami",
          "; id",
          ";id",
          "; uname",
          ";uname",
          "cmd.exe",
          "powershell",
          "windows\\system32",
          "c:\\windows",
        ]
        field_to_match = "all_query_arguments"
      }
    },
    {
      name     = "block-ldap-injection"
      priority = 101
      action   = "block"
      statement = {
        patterns = [
          ")(uid=",
          "*)(&",
          ")(|(",
        ]
        field_to_match = "all_query_arguments"
      }
    }
  ]
}

module "waf_dvwa" {
  source         = "../modules/waf"
  name           = "seoul-waf-dvwa"
  description    = "WAF for DVWA ALB"
  scope          = "REGIONAL"
  default_action = "allow"

  alb_arn       = module.alb_dvwa.alb_arn
  metric_name   = "waf-dvwa"
  



  managed_rule_groups = [
    {
      name            = "AWSManagedRulesCommonRuleSet"
      vendor_name     = "AWS"
      priority        = 10
      override_action = "none"
    },
    {
      name            = "AWSManagedRulesSQLiRuleSet"
      vendor_name     = "AWS"
      priority        = 20
      override_action = "none"
    }
  ]

  rate_limit = 2000
}



module "asg_dvwa" {
  source = "../modules/asg"

  name          = "${local.vars.region_name}-dvwa-asg"
  ami           = local.vars.asg.ami
  instance_type = local.vars.asg.instance_type
  key_name      = module.keypair.key_name

  security_group_id           = module.security_group.sg_ids["web"]
  subnet_ids                  = module.vpc.public_subnet_ids
  associate_public_ip_address = true

  desired_capacity = local.vars.asg.desired_capacity
  min_size         = local.vars.asg.min_size
  max_size         = local.vars.asg.max_size

  target_group_arns = [module.alb_dvwa.target_group_arn]
  user_data         = local.dvwa_user_data
}

module "asg_gnuboard" {
  source = "../modules/asg"

  name          = "${local.vars.region_name}-gnuboard-asg"
  ami           = local.vars.asg.ami
  instance_type = local.vars.asg.instance_type
  key_name      = module.keypair.key_name

  security_group_id           = module.security_group.sg_ids["web"]
  subnet_ids                  = module.vpc.public_subnet_ids
  associate_public_ip_address = true

  desired_capacity = local.vars.asg.desired_capacity
  min_size         = local.vars.asg.min_size
  max_size         = local.vars.asg.max_size

  target_group_arns = [module.alb_gnuboard.target_group_arn]
  user_data         = local.gnuboard_user_data
}

module "asg_wordpress" {
  source = "../modules/asg"

  name          = "${local.vars.region_name}-wordpress-asg"
  ami           = local.vars.asg.ami
  instance_type = local.vars.asg.instance_type
  key_name      = module.keypair.key_name

  security_group_id           = module.security_group.sg_ids["web"]
  subnet_ids                  = module.vpc.public_subnet_ids
  associate_public_ip_address = true

  desired_capacity = local.vars.asg.desired_capacity
  min_size         = local.vars.asg.min_size
  max_size         = local.vars.asg.max_size

  target_group_arns = [module.alb_wordpress.target_group_arn]
  user_data         = local.wordpress_user_data
}


module "ec2" {
  source = "../modules/ec2"

  region_name        = local.vars.region_name
  az_list            = module.vpc.az_list
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  sg_ids             = module.security_group.sg_ids
  key_name           = module.keypair.key_name
  public_key_openssh = module.keypair.public_key

  ec2_instances = {
    db = {
      count         = 1
      ami           = local.vars.asg.ami
      instance_type = local.vars.asg.instance_type
      sg_name       = "web" # SSH 열려있는 SG로 우선 사용(필요하면 db-sg 따로 만들면 됨)
      public        = true  # 퍼블릭 IP 필요하니까 true
      user_data     = ""
    }
  }
}

module "route53" {
  source    = "../modules/route53"
  zone_name = "iac.it-edu.org"

  records = {
    # dvwa.iac.it-edu.org → DVWA ALB DNS
    "dvwa" = {
      type = "CNAME"
      ttl  = 60
      records = [
        module.alb_dvwa.dns_name
      ]
    }

    # gnuboard.iac.it-edu.org → GNUBoard ALB DNS
    "gnuboard" = {
      type = "CNAME"
      ttl  = 60
      records = [
        module.alb_gnuboard.dns_name
      ]
    }
    "wordpress" = {
      type    = "CNAME"
      ttl     = 60
      records = [module.alb_wordpress.dns_name]
    }

    # db.iac.it-edu.org → RDS Endpoint DNS
    "db" = {
      type = "CNAME"
      ttl  = 60
      records = [
        module.rds.address
      ]
    }
  }
}





resource "local_file" "private_key" {
  content  = module.keypair.private_key
  filename = "${path.module}/id_${lower(local.vars.key_info.algorithm)}"
}

resource "local_file" "public_key" {
  content  = module.keypair.public_key
  filename = "${path.module}/id_${lower(local.vars.key_info.algorithm)}.pub"
}



output "wordpress_fqdn" {
  value = module.route53.record_fqdns["wordpress"]
}

output "dvwa_fqdn" {
  value = module.route53.record_fqdns["dvwa"]
}

output "gnuboard_fqdn" {
  value = module.route53.record_fqdns["gnuboard"]
}

output "db_fqdn" {
  value = module.route53.record_fqdns["db"]
}


output "web_urls" {
  value = {
    dvwa      = "http://${module.route53.record_fqdns["dvwa"]}/"
    gnuboard  = "http://${module.route53.record_fqdns["gnuboard"]}/"
    wordpress = "http://${module.route53.record_fqdns["wordpress"]}/"
  }
}


output "rds_endpoint" {
  value = module.rds.endpoint
}

output "efs_id" {
  value = module.efs.file_system_id

}
