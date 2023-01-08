resource "aws_cloudfront_function" "rewrite_uri" {
  name    = "rewrite-request"
  runtime = "cloudfront-js-1.0"
  publish = true

  code = <<EOF
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    
    // Check whether the URI is missing a file name.
    if (uri.endsWith('/')) {
        request.uri += 'index.html';
    } 
    // Check whether the URI is missing a file extension.
    else if (!uri.includes('.')) {
        request.uri += '/index.html';
    }

    return request;
}
EOF
}


## Lambda function that stop and start rds:
module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "4.7.1"

  function_name = "StopRds"
  description   = "Lambda function to stop Rds."
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  source_path = "../lambda/stop_rds"

  tags = {
    Name = "StopRds"
  }
}