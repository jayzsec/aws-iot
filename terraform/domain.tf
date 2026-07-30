#################################################
# Custom Domain - Cloudflare
#################################################

# Fetch Cloudflare Zone ID
data "cloudflare_zone" "zone" {
  filter = {
    name = var.domain_name
  }
}

# Request ACM Certificate in us-east-1
resource "aws_acm_certificate" "cloudfront_cert" {
  provider          = aws.us_east_1
  domain_name       = var.subdomain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Create ACM validation CNAME record in cloudflare
resource "cloudflare_dns_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cloudfront_cert.domain_validation_options : dvo.domain_name => {
      name    = dvo.resource_record_name
      content = dvo.resource_record_value
      type    = dvo.resource_record_type
    }
  }

  zone_id = data.cloudflare_zone.zone.id
  name    = each.value.name
  content = each.value.content
  type    = each.value.type
  proxied = false # gray cloud or DNS only - for ACM validation
  ttl     = 60
}

# Wait for ACM DNS validation to complete
resource "aws_acm_certificate_validation" "cert_validation" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront_cert.arn
  validation_record_fqdns = [for record in cloudflare_dns_record.acm_validation : record.name]
}

# Create Routing CNAME record in Cloudflare -> Cloudfront
resource "cloudflare_dns_record" "app_cname" {
  zone_id = data.cloudflare_zone.zone.id
  name    = "iot"
  content = aws_cloudfront_distribution.frontend_cdn.domain_name
  type    = "CNAME"
  proxied = true # orange cloud - cloudflare ddos / edge feature is on
  ttl     = 1
}