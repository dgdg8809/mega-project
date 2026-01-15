resource "aws_wafv2_web_acl" "this" {
  name        = var.name
  description = var.description
  scope       = var.scope

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }
    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.metric_name
    sampled_requests_enabled   = true
  }

  # (선택) Rate-based rule
  dynamic "rule" {
    for_each = var.rate_limit > 0 ? [1] : []
    content {
      name     = "rate-limit"
      priority = 0

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.rate_limit
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.metric_name}-rate"
        sampled_requests_enabled   = true
      }
    }
  }

  # Managed Rule Groups
  dynamic "rule" {
    for_each = var.managed_rule_groups
    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        dynamic "none" {
          for_each = rule.value.override_action == "none" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = rule.value.override_action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = rule.value.vendor_name
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.metric_name}-${rule.value.name}"
        sampled_requests_enabled   = true
      }
    }
  }

  # Custom Rules (Command Injection, LDAP Injection 등 차단)
  dynamic "rule" {
    for_each = var.custom_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        dynamic "block" {
          for_each = rule.value.action == "block" ? [1] : []
          content {}
        }
        dynamic "allow" {
          for_each = rule.value.action == "allow" ? [1] : []
          content {}
        }
      }

      statement {
        or_statement {
          dynamic "statement" {
            for_each = rule.value.statement.patterns
            content {
              byte_match_statement {
                search_string         = base64encode(statement.value)
                positional_constraint = "CONTAINS"

                dynamic "field_to_match" {
                  for_each = rule.value.statement.field_to_match == "uri" ? [1] : []
                  content {
                    uri_path {}
                  }
                }

                dynamic "field_to_match" {
                  for_each = rule.value.statement.field_to_match == "query_string" || rule.value.statement.field_to_match == "all_query_arguments" ? [1] : []
                  content {
                    all_query_arguments {}
                  }
                }

                dynamic "field_to_match" {
                  for_each = rule.value.statement.field_to_match == "body" ? [1] : []
                  content {
                    body {}
                  }
                }

                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }

                text_transformation {
                  priority = 1
                  type     = "URL_DECODE"
                }

                text_transformation {
                  priority = 2
                  type     = "HTML_ENTITY_DECODE"
                }

                text_transformation {
                  priority = 3
                  type     = "REMOVE_NULLS"
                }
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.metric_name}-${rule.value.name}"
        sampled_requests_enabled   = true
      }
    }
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "/aws/waf/${var.name}"
  retention_in_days = var.log_retention_days
}


