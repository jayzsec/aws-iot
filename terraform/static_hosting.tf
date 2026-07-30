#####################################################
# S3 BUCKET FOR ASTRO FRONTEND STATIC ASSETS
#####################################################

# Random Suffix for Globally Unique S3 Bucket Name
resource "random_string" "bucket_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Private s3 Bucket
resource "aws_s3_bucket" "frontend_bucket" {
  bucket        = "${var.project_name}-${var.environment}-frontend-${random_string.bucket_suffix.result}"
  force_destroy = true # Allows easy tear-down during development

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Block all public access to s3
resource "aws_s3_bucket_public_access_block" "frontend_bucket_public_block" {
  bucket                  = aws_s3_bucket.frontend_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#####################################################
# CLOUDFRONT ORIGIN ACCESS CONTROL (OAC) & CDN
#####################################################

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "${var.project_name}-${var.environment}-oac"
  description                       = "OAC for Astro Frontend S3 Bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "frontend_cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} Frontend Distribution"
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.frontend_bucket.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true

    # Attach the cloudfront function here
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.astro_router.arn
    }
  }

  # SPA Routing Support: Redirect 403 / 404 to index.html
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # add custom domain alias
  aliases = [var.subdomain]

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert_validation.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2025"
    # cloudfront_default_certificate = true
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

#####################################################
# S3 BUCKET POLICY - ALLOW CLOUDFRONT OAC ONLY
#####################################################

# Bucket Policy Granting CloudFront GetObject Permission
resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontServicePrincipalReadOnly"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.frontend_bucket.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.frontend_cdn.arn
        }
      }
    }]
  })
}

#####################################################
# CLOUDFRONT FUNCTION FOR ASTRO SUBFOLDER ROUTING
#####################################################

# URL Rewrite Function for Astro SSG Routes - /login -> /login/index.html
resource "aws_cloudfront_function" "astro_router" {
  name    = "${var.project_name}-${var.environment}-astro-router"
  runtime = "cloudfront-js-2.0"
  comment = "Appends index.html to subfolder requests for Astro static site routing"
  publish = true

  code = <<EOF
function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // If URI ends with '/', append index.html
    if (uri.endsWith('/')) {
        request.uri += 'index.html';
    }
    // If URI has no file extension (e.g., /login), append /index.html
    else if (!uri.includes('.')) {
        request.uri += '/index.html';
    }

    return request;
}
EOF
}